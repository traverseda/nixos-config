# nanobot.nix
{ config, pkgs, inputs, lib, mkUvScriptEnv, mkMcpService, mcpConnect, nanobotSandboxed, ... }:
let
  mcpTools = {
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

  systemd.user.services = lib.mapAttrs mkMcpService mcpTools;

  home.file.".nanobot/config.json".text = builtins.toJSON {
    providers = {
      openrouter = {
        apiKey = "\${OPENROUTER_API_KEY}";
      };
    };

    agents.defaults = {
      workspace           = "~/.nanobot/workspace";
      model               = "anthropic/claude-opus-4-5";
      provider            = "auto";
      maxTokens           = 8192;
      contextWindowTokens = 65536;
      temperature         = 0.1;
      maxToolIterations   = 200;
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
