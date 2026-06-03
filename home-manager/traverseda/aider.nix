{ config, lib, pkgs, ... }:

{
  home.packages = [
    pkgs.unstable.aider-chat

    (pkgs.writeShellScriptBin "autocommit" ''
      aider --commit
    '')
  ];

  home.sessionVariables = {
    AIDER_MODEL = "${config.home.sessionVariables.AI_STRONG_PROVIDER}/${config.home.sessionVariables.AI_STRONG_MODEL}";
    AIDER_WEAK_MODEL = "${config.home.sessionVariables.AI_WEAK_PROVIDER}/${config.home.sessionVariables.AI_WEAK_MODEL}";
  };

  home.file.".aider.conf.yml" = {
    text = ''
      dark-mode: true
      read: AGENTS.md
      watch-files: true
    '';
  };
}
