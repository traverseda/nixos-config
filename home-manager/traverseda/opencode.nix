{ config, lib, pkgs, ... }:

{
  programs.opencode = {
    enable = true;
    settings = {
      provider.openrouter.models = {
        "${config.home.sessionVariables.AI_STRONG_MODEL}" = { };
        "${config.home.sessionVariables.AI_WEAK_MODEL}" = { };
      };
      mcp.tavily = {
        type = "remote";
        url = "https://mcp.tavily.com/mcp/?tavilyApiKey={env:TAVILY_API_KEY}";
      };
    };
  };
}