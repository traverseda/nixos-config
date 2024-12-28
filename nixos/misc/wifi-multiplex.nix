{ pkgs, lib, ... }:

let
  # Define a udev rule that triggers a systemd service
  wifiUdevRule = ''
    ACTION=="add", SUBSYSTEM=="net", ENV{DEVTYPE}=="wlan", KERNEL!="virt_*", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}="add-virt-interface@%k.service"
  '';
in
{
  environment.systemPackages = with pkgs; [
    iw
  ];

  services.udev.extraRules = ''
    ${wifiUdevRule}
  '';

  systemd.services."add-virt-interface@".serviceConfig = {
    Type = "oneshot";
    ExecStart = "${pkgs.iw}/bin/iw dev %i interface add virt_%i_ap type __ap";
  };
  systemd.services."add-virt-interface@".path = [ pkgs.iw ];
}
