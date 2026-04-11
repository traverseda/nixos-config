  { config, lib, pkgs, ... }:

  let
    cfg = config.nanobot;

    mkMcpService = name: tool:
      let
        # Generate the exact command string once
        firejailBin = "/run/wrappers/bin/firejail";
        mcpBin = "${tool.package}/bin/${tool.bin}";

        # Combine all flags into a single list
        allArgs = [ "--private" "--quiet" ]
                  ++ (tool.firejailArgs or [])
                  ++ (map (v: "--env=''${v}") (tool.env or []))
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
          Unit.Description = "Sandboxed MCP gateway for ${name}";
          Service = {
            # Socat runs the script; script execs bash; bash execs firejail.
            ExecStart = "${pkgs.socat}/bin/socat UNIX-LISTEN:%t/mcp/${name}.sock,fork,reuseaddr EXEC:${launcher},sigint";

            Restart = "always";
            RestartSec = "3s";
            ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p %t/mcp";
          };
          Install.WantedBy = [ "default.target" ];
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

    config = lib.mkIf (cfg.tools != {}) {
      systemd.user.services = lib.mapAttrs' mkMcpService cfg.tools;
    };
  }
