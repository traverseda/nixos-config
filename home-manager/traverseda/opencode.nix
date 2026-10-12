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
      provider = {
        openrouter.models = {
          "${config.home.sessionVariables.AI_WEAK_MODEL}" = {};
          "${config.home.sessionVariables.AI_VISION_MODEL}" = {};
        };
        "${config.home.sessionVariables.AI_STRONG_PROVIDER}" = {
          npm = "@ai-sdk/openai-compatible";
          name = "Spiri LLM";
          options = {
            baseURL = "https://llm.internal.spiri.ca/v1";
            apiKey = "{env:VLLM_API_KEY}";
          };
          models."${config.home.sessionVariables.AI_STRONG_MODEL}" = {};
        };
      };
      mcp.tavily = {
        type = "remote";
        url = "https://mcp.tavily.com/mcp/?tavilyApiKey={env:TAVILY_API_KEY}";
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
      ];
    };
  };

  xdg.configFile."opencode/opencode-vision.json".text = builtins.toJSON {
    models = ["*deepseek*" "*llama*"];
    imageAnalysisTool = "openrouter_image_analyze_image";
  };
}
