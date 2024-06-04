{ pkgs, lib, ... }:

let
  wifiUdevRule = ''
    ACTION=="add", SUBSYSTEM=="net", ENV{DEVTYPE}=="wlan", !KERNEL=="phy*", RUN+="${pkgs.iw}/bin/iw dev %k info | grep -q '_ap' || ${pkgs.iw}/bin/iw dev %k interface add %k_ap type station"
  '';
in
{
  environment.systemPackages = with pkgs; [
    iw
  ];

  services.udev.extraRules = wifiUdevRule;
}
