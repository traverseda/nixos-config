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
    plugins.clipboard-image.enable = true;
  };

  home.packages = [
    pkgs.xclip
    pkgs.ripgrep
    pkgs.jq
    pkgs.tree
    pkgs.curl
    pkgs.wget
  ];


  programs.bash = {
    enable = true;
    enableCompletion = true;
  };

  programs.home-manager.enable = true;

  home.stateVersion = "23.05";
}
