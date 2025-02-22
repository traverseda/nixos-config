{ pkgs, lib, ... }:

let
  # Udev rule to trigger the systemd service when a WiFi device is added
  wifiUdevRule = ''
    ACTION=="add", SUBSYSTEM=="net", ENV{DEVTYPE}=="wlan", KERNEL!="*_ap", \
    TAG+="systemd", ENV{SYSTEMD_WANTS}="add-virt-interface@%k.service"
  '';
in
{
  environment.systemPackages = with pkgs; [ iw ];

  services.udev.extraRules = ''
    ${wifiUdevRule}
  '';

  systemd.services."add-virt-interface@" = {
    description = "Add virtual AP interface for %i";
    after = [ "network.target" ];
    wants = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.iw}/bin/iw dev %i interface add %i_ap type __ap";
      RemainAfterExit = true;
      Restart = "on-failure";
    };
    path = [ pkgs.iw ];
  };
}
