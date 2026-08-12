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
