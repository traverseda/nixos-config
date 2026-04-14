# nanobot.nix
{ config, pkgs, inputs, lib, mkUvScriptEnv, nanobotSandboxed, ... }:
let
  craneLib = inputs.crane.mkLib pkgs;

  mcpConnect = pkgs.writeShellScriptBin "mcp-connect" ''
    exec ${pkgs.socat}/bin/socat STDIO UNIX-CONNECT:"/run/user/$(id -u)/mcp/$1.sock"
  '';

  anytypeMcp = pkgs.buildNpmPackage {
    pname = "anytype-mcp";
    version = "1.2.5";
    src = pkgs.fetchFromGitHub {
      owner = "anyproto";
      repo = "anytype-mcp";
      rev = "main";
      hash = "sha256-N/6mospk2aFFecPo+nvgDc5m79N0sngtRcxC9yyO2qU=";
    };
    npmDepsHash = "sha256-V33PPWVnsTXCTi7gRZDuw17bArZak/3V0GvWkfGbayQ=";
  };

  anytypeWrapper = pkgs.writeShellScriptBin "anytype-mcp-wrapper" ''
    export OPENAPI_MCP_HEADERS="{\"Authorization\":\"Bearer $ANYTYPE_API_KEY\", \"Anytype-Version\":\"2025-11-08\"}"
    exec ${anytypeMcp}/bin/anytype-mcp
  '';
in
{
  imports = [ ./nanobot_old.nix ./mcp_tools.nix ./nanobot_gateway.nix ];

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
      package = mkUvScriptEnv ./tools/nix.py [ ];
      bin = "mcp-nixos";
      env = [ ];
      firejailArgs = [ "--caps.drop=all" "--private" ];
    };
    anytype = {
      package = anytypeWrapper;
      bin = "anytype-mcp-wrapper";
      env = [ "ANYTYPE_API_KEY" "ANYTYPE_API_BASE_URL" ];
      firejailArgs = [ "--caps.drop=all" "--private" ];
    };
    # treesitter = {
    #   package = mkUvScriptEnv ./tools/treesitter.py [];
    #   bin="mcp-server-tree-sitter";
    #   env = [];
    #   firejailArgs = [];
    # };
  };


  home.file.".nanobot/config.json".text = builtins.toJSON {
    providers = {
      openrouter = {
        apiKey = "\${OPENROUTER_API_KEY}";
      };
    };

    agents.defaults = {
      workspace           = "~/.nanobot/workspace";
      model               = "deepseek/deepseek-v3.2";
      provider            = "auto";
      maxTokens           = 4096;
      contextWindowTokens = 32000;
      temperature         = 0.4;
      maxToolIterations   = 15;
      maxToolResultChars  = 16000;
      providerRetryMode   = "standard";
      timezone            = "America/Halifax";
      dream = {
        intervalH     = 2;
        maxBatchSize  = 20;
        maxIterations = 10;
      };
    };

    api = {
      host = "127.0.0.1";
      port = 8900;
      timeout = 120.0;
    };

    gateway = {
      host = "127.0.0.1";
      port = 18790;
      heartbeat = {
        enabled = true;
        intervalS = 1800;
        keepRecentMessages = 8;
      };
    };

    tools = {
      restrictToWorkspace = true;
      mcpServers = lib.mapAttrs (name: _: {
        command = "${mcpConnect}/bin/mcp-connect";
        args = [ name ];
      }) config.nanobot.tools;
    };
  };

  home.packages = [ nanobotSandboxed mcpConnect ];
}