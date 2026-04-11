{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.nanobot;

  python = pkgs.python313;

  baseSet = pkgs.callPackage inputs.pyproject-nix.build.packages {
    inherit python;
  };

  mkUvScriptEnv = scriptFile:
    let
      script = inputs.uv2nix.lib.scripts.loadScript {
        script = ./tools + "/${scriptFile}";
      };
      overlay = script.mkOverlay { sourcePreference = "wheel"; };
      pythonSet = baseSet.overrideScope (
        lib.composeManyExtensions [
          inputs.pyproject-build-systems.overlays.wheel
          overlay
        ]
      );
    in
      script.mkVirtualEnv { inherit pythonSet; };

  mkMcpService = name: tool:
    let
      # Generate the exact command string once
      firejailBin = "/run/wrappers/bin/firejail";
      mcpBin = "${tool.package}/bin/${tool.bin}";

      # Combine all flags into a single list
      allArgs = [ "--private" "--quiet" ]
                ++ (tool.firejailArgs or [])
                ++ (map (v: "--env=${v}=\${${v}}") (tool.env or []))
                ++ [ "--" mcpBin ];

      fullCmd = "${firejailBin} ${lib.concatStringsSep " " allArgs}";

      # Create a script that executes that single line
      launcher = pkgs.writeShellScript "mcp-${name}-launcher" ''
        # Use --login to get API keys, then exec the firejail command
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
          # Socat runs the script; script execs bash; bash execs firejail.
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
        firejailArgs = lib.mkOption { type = lib.types.listOf lib.types.str; default = []; };
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
