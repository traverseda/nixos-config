{ config, pkgs, lib, ros, ... }:

{
  virtualisation.virtualbox.host.enable = true;
  users.extraGroups.vboxusers.members = [ "traverseda" ];
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  environment.systemPackages = with pkgs; [
    pkgs.qgroundcontrol
    pkgs.vscode
    pkgs.stdenv
    pkgs.gcc
    pkgs.rustc
    pkgs.cargo
    pkgs.zig
    pkgs.kompare
    pkgs.distrobox
    pkgs.element-desktop
    pkgs.act
    pkgs.logseq
  ];
}

