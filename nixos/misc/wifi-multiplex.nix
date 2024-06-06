
{ pkgs, lib, ... }:

let
  wifiUdevRule = ''
    ACTION=="add", SUBSYSTEM=="net", ENV{DEVTYPE}=="wlan",  ENV{ID_NET_NAME_MAC}=="", RUN+="/bin/sh -c '${pkgs.iw}/bin/iw dev %k interface add %k_ap type station'"

  '';
in
{
  environment.systemPackages = with pkgs; [
    iw
  ];

  services.udev.extraRules = wifiUdevRule;
}
