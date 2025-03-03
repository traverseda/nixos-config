{ config, pkgs, lib, ... }:

{

  programs.steam = {
    enable = true;
    # remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
  };
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin];

  programs.gamescope.enable = true;
  programs.gamemode.enable = true;

  environment.systemPackages =[
    pkgs.discord
    pkgs.heroic
  ];
}

