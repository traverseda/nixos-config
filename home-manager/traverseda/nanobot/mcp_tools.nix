{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.nanobot;

  python = pkgs.python313;

  baseSet = pkgs.callPackage inputs.pyproject-nix.build.packages {
    inherit python;
  };

  mkUvScriptEnv = script: extraPackages:
    let
      scriptData = inputs.uv2nix.lib.scripts.loadScript {
        inherit script;
      };
      overlay = scriptData.mkOverlay { sourcePreference = "wheel"; };
      pythonSet = baseSet.overrideScope (
        lib.composeManyExtensions [
          inputs.pyproject-build-systems.overlays.wheel
          overlay
          (final: prev: 
            # Convert list of package objects to an attribute set
            lib.listToAttrs (map (p: { name = lib.getName p; value = p; }) extraPackages)
          )
        ]
      );
    in
      scriptData.mkVirtualEnv { inherit pythonSet; };

  mkMcpService = name: tool:
    let
      bwrapBin = "${pkgs.bubblewrap}/bin/bwrap";
      mcpBin = "${tool.package}/bin/${tool.bin}";

      # Build bubblewrap arguments for isolation
      bwrapArgs =
        [ "--unshare-all" "--die-with-parent"
          "--ro-bind /nix/store/ /nix/store/"
          "--ro-bind /etc/resolv.conf /etc/resolv.conf"
          "--ro-bind /etc/hosts /etc/hosts"
        ]
        ++ (tool.bwrapArgs or [])
        ++ (map (v: "--setenv ${v} \${${v}}") (tool.env or []))
        ++ [ mcpBin ];

      fullCmd = "${bwrapBin} ${lib.concatStringsSep " " bwrapArgs}";

      launcher = pkgs.writeShellScript "mcp-${name}-launcher" ''
        exec ${pkgs.bash}/bin/bash --login -c ${lib.escapeShellArg fullCmd} 2> >(systemd-cat -t mcp-${name})
      '';
    in {
      name = "mcp-${name}";
      value = {
        Unit = {
          Description = "Sandboxed MCP gateway for ${name}";
          PartOf = [ "mcp.target" ];
        };
        Service = {
          ExecStart = "${pkgs.socat}/bin/socat UNIX-LISTEN:%t/mcp/${name}.sock,fork,reuseaddr EXEC:${launcher},sigint";
          Restart = "always";
          RestartSec = "3s";
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %t/mcp";
        };
        Install.WantedBy = [ "mcp.target" ];
      };
    };

in {
  options.nanobot.tools = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        package = lib.mkOption { type = lib.types.package; };
        bin = lib.mkOption { type = lib.types.str; };
        env = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
        bwrapArgs = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
      };
    });
    default = {};
  };

  config = {
    systemd.user.targets.mcp = {
      Unit = {
        Description = "Target for all MCP services";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    systemd.user.services = lib.mkIf (cfg.tools != {}) (lib.mapAttrs' mkMcpService cfg.tools);
    _module.args = { inherit mkUvScriptEnv; };
  };
}
