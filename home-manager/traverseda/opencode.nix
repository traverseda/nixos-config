{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.opencode = {
    enable = true;
    extraPackages = [pkgs.nixd pkgs.nixpkgs-fmt pkgs.pyright];
    settings = {
      lsp = true;
      provider.openrouter.models = {
        "${config.home.sessionVariables.AI_STRONG_MODEL}" = {};
        "${config.home.sessionVariables.AI_WEAK_MODEL}" = {};
        "${config.home.sessionVariables.AI_VISION_MODEL}" = {};
      };
      mcp.tavily = {
        type = "remote";
        url = "https://mcp.tavily.com/mcp/?tavilyApiKey={env:TAVILY_API_KEY}";
      };
      mcp.xaelwiki = {
        type = "remote";
        url = "http://hermes.tail1905aa.ts.net:8000/mcp";
        headers.Authorization = "Bearer {env:XAEL_AUTH_TOKEN}";
      };
      mcp.openrouter_image = {
        type = "local";
        command = ["${pkgs.openrouter-image-mcp}/bin/openrouter-image-mcp"];
        environment = {
          OPENROUTER_API_KEY = "{env:OPENROUTER_API_KEY}";
          OPENROUTER_MODEL = "{env:AI_VISION_MODEL}";
        };
      };
      mcp.playwright = {
        type = "local";
        command = ["${pkgs.playwright-mcp}/bin/playwright-mcp"];
        environment.PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright.browsers}";
      };
      plugin = [
        "file://${pkgs.opencode-vision}/dist/index.js"
        [
          "@vectorize-io/opencode-hindsight"
          {
            hindsightApiUrl = "http://hermes.tail1905aa.ts.net:8888";
            bankId = "code";
          }
        ]
      ];
    };
  };

  xdg.configFile."opencode/opencode-vision.json".text = builtins.toJSON {
    models = ["*deepseek*" "*llama*"];
    imageAnalysisTool = "openrouter_image_analyze_image";
  };
}
