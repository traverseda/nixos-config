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
        url = "https://notes.0u0.ca/mcp";
        headers.Authorization = "Bearer {env:XAEL_AUTH_TOKEN}";
      };
      mcp.vision = {
        type = "local";
        command = ["${pkgs.opencode-vision}/bin/opencode-vision"];
        environment = {
          VISION_PROVIDER = "openrouter";
          OPENROUTER_API_KEY = "{env:OPENROUTER_API_KEY}";
          OPENROUTER_MODEL = "{env:AI_VISION_MODEL}";
        };
        timeout = 30000;
      };
      mcp.playwright = {
        type = "local";
        command = ["${pkgs.playwright-mcp}/bin/playwright-mcp"];
        environment.PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright.browsers}";
      };
      plugin = [
        [
          "@vectorize-io/opencode-hindsight"
          {
            hindsightApiUrl = "https://hindsight-api.0u0.ca";
            bankId = "code";
          }
        ]
      ];
    };
  };
}
