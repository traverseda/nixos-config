{ pkgs, lib, ... }:

let
  wifiUdevRule = ''
    ACTION=="add", SUBSYSTEM=="net", ENV{DEVTYPE}=="wlan", KERNEL!="virt_", RUN+="${pkgs.iw}/bin/iw dev %k interface add virt_%k_ap type station"
  '';
in
{
  environment.systemPackages = with pkgs; [
    iw
  ];

  services.udev.extraRules = wifiUdevRule;
}
