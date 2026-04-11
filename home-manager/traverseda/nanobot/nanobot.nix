# nanobot.nix
{ config, pkgs, inputs, lib, mkUvScriptEnv, mkMcpBundle, mcpConnect, nanobotSandboxed, ... }:
let
  craneLib = inputs.crane.mkLib pkgs;
  mcpTools = {

  };

  mcpConnect = pkgs.writeShellScriptBin "mcp-connect" ''                                                                                                                                    
    exec ${pkgs.socat}/bin/socat STDIO UNIX-CONNECT:"/run/user/$(id -u)/mcp/$1.sock"                                                                                                            
  '';      
in
{
  imports = [ ./nanobot_old.nix ./mcp_tools.nix ];

  nanobot.tools = { 
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
      firejailArgs = [ "--caps.drop=all --noprofile" ];
    };
     vscode = {
       package = pkgs.mcp-proxy;
       bin     = "mcp-proxy http://127.0.0.1:3777/mcp --transport=streamablehttp";
       env     = [ ];
       firejailArgs = [ "--caps.drop=all" ]; # No --private here, we need to talk to localhost
     };
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
      maxTokens           = 4096;
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
      args = [ name ];                                                                                                                                                                      
    }) config.nanobot.tools; 
  };

  home.packages = [ nanobotSandboxed mcpConnect ];
}
