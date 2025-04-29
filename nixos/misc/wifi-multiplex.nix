{ pkgs, lib, ... }:
{

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
