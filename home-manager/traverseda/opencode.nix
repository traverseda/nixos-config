{ config, lib, pkgs, ... }:

{
  programs.opencode = {
    enable = true;
    settings = {
      provider.openrouter.models = {
        "${config.home.sessionVariables.AI_STRONG_MODEL}" = { };
        "${config.home.sessionVariables.AI_WEAK_MODEL}" = { };
      };
    };
  };
}