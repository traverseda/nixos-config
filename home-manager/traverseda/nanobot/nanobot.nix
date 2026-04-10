# nanobot.nix
{ config, pkgs, inputs, lib, mkUvScriptEnv, mkMcpService, mcpConnect, nanobotSandboxed, mkCargoEnv, ... }:
let
  craneLib = inputs.crane.mkLib pkgs;
  mcpTools = {
    # Very expensive, AI can sort through crap alright.
    # kagimcp = {
    #   package      = mkUvScriptEnv "mcp_kagi.py";
    #   bin          = "kagimcp";
    #   firejailArgs = [ "--caps.drop=all" "--private" ];
    #   env          = [ "KAGI_API_KEY" ];
    # };
    homeAssistant = {
      package = pkgs.mcp-proxy;
      bin = "mcp-proxy https://hearth.0u0.ca/api/mcp --transport=streamablehttp --stateless --headers Authorization \"Bearer \${HOME_ASSISTANT_API_KEY}\"";
      env = [ "HOME_ASSISTANT_API_KEY" ];
      firejailArgs = [ "--caps.drop=all" "--private" ];
    };

     vscode = {
       package = pkgs.mcp-proxy;
       bin     = "mcp-proxy http://127.0.0.1:3777/mcp --transport=streamablehttp";
       env     = [ ];
       firejailArgs = [ "--caps.drop=all" ]; # No --private here, we need to talk to localhost
     };

    clipboard = {
      package = craneLib.buildPackage {
        src = pkgs.fetchFromGitHub {
          owner = "mnardit";
          repo  = "clipboard-mcp";
          rev   = "main";
          hash  = "sha256-URJg4fKFxtpJe+LsKbsn2biLdY2+PKWL9ePlXwFzz0U=";
        };
      };
      bin = "clipboard-mcp";
      env = [ ];
      firejailArgs = [ "--caps.drop=all" ];
    };

    nixos = {
      package = mkUvScriptEnv "nix.py";
      bin = "mcp-nixos";
      env = [ ];
      firejailArgs = [ "--caps.drop=all" "--private" ];
    };
  };

in
{
  imports = [ ./nanobot_tools.nix ];

  systemd.user.services = (lib.mapAttrs mkMcpService mcpTools) // {
    nanobot-gateway = {
      Unit = {
        Description = "nanobot Gateway Service";
        After = [ "network.target" ];
      };
      Service = {
        ExecStart = "${nanobotSandboxed}/bin/nanobot gateway --port 8000";
        Restart = "always";
        RestartSec = "5s";
        Environment = [
          "XDG_RUNTIME_DIR=/run/user/%U"
          "PATH=${lib.makeBinPath [ pkgs.firejail ]}"
        ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };

  home.file.".nanobot/config.json".text = builtins.toJSON {
    providers = {
      openrouter = {
        apiKey = "\${OPENROUTER_API_KEY}";
      };
    };

    agents.defaults = {
      workspace           = "~/.nanobot/workspace";
      model               = "google/gemini-3-flash-preview";
      provider            = "auto";
      maxTokens           = 8192;
      contextWindowTokens = 32000;
      temperature         = 0.7;
      maxToolIterations   = 20;
      maxToolResultChars  = 16000;
      providerRetryMode   = "standard";
      timezone            = "UTC";
      dream = {
        intervalH     = 2;
        maxBatchSize  = 20;
        maxIterations = 10;
      };
    };

    tools.mcpServers = lib.mapAttrs (name: _: {
      command = "${mcpConnect}/bin/mcp-connect";
      args    = [ name ];
    }) mcpTools;
  };



  home.packages = [ nanobotSandboxed mcpConnect ];
}
