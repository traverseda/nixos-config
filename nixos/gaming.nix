{ config, pkgs, lib, ... }:

{

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
  };

  environment.systemPackages =[
    pkgs.discord
  ];
}

