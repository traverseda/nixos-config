{ config, pkgs, lib, inputs, ... }:

{

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    gamescopeSession.enable = true;

  };
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin];
  programs.gamemode.enable = true;
  environment.systemPackages = [
    pkgs.mangohud
    pkgs.moonlight-qt
  ];

}

