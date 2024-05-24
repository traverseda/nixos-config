{ config, pkgs, lib, ros, ... }:

{
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "traverseda" ];

  environment.systemPackages = with pkgs; [
    pkgs.qgroundcontrol
    pkgs.distrobox
    pkgs.element-desktop
    pkgs.logseq
  ];
}

