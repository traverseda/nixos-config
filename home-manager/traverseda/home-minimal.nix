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
    settings = {
      user = {
        name = "Alex Davies";
        email = "traverse.da@gmail.com";
      };
      push = {
        autoSetupRemote = true; # Automatically set upstream when pushing
      };
    };
  };

  home.packages = [
    pkgs.xclip
    pkgs.ripgrep
    pkgs.jq
    pkgs.tree
    pkgs.curl
    pkgs.wget
    pkgs.mosh
    pkgs.sshuttle
  ];


  programs.bash = {
    enable = true;
    enableCompletion = true;
  };

  programs.home-manager.enable = true;

  home.stateVersion = "23.05";
}
