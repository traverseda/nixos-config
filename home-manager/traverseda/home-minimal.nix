# This is a minimal home-manager configuration file
# Use this to configure a lightweight home environment
{
  inputs,
  outputs,
  config,
  pkgs,
  specialArgs,
  ...
}: {
  imports = [
    (import ./nixvim.nix { inherit pkgs; })
  ];

  nixpkgs = {
    overlays = [];
    config = {
      allowUnfree = false;
    };
  };

  home = {
    username = specialArgs.homeUser or "traverseda";
    homeDirectory = specialArgs.homeDir or "/home/traverseda";
  };

  programs.git = {
    enable = true;
    userName = "Alex Davies";
    userEmail = "traverse.da@gmail.com";
  };

  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  home.packages = [
    pkgs.zsh
    pkgs.xclip
    pkgs.ripgrep
    pkgs.jq
    pkgs.tree
    pkgs.curl
    pkgs.wget
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    history.size = 1000;
    history.path = "${config.xdg.dataHome}/zsh/history";
  };

  programs.bash = {
    enable = true;
    enableCompletion = true;
  };

  programs.home-manager.enable = true;

  home.stateVersion = "23.05";
}
