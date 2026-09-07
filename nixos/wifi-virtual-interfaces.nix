# Adds ap0 (AP) and mon0 (monitor) virtual interfaces on top of the
# physical wlp194s0 radio. Waits for NetworkManager to finish bringing up
# the managed connection first, since adding virtual interfaces before the
# radio has associated can upset it.
{pkgs, ...}: {
  systemd.services.wifi-virtual-interfaces = {
    description = "Add ap0 and mon0 virtual interfaces on wlp194s0";
    after = ["NetworkManager-wait-online.service"];
    wants = ["NetworkManager-wait-online.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${pkgs.iw}/bin/iw dev wlp194s0 interface add ap0 type __ap"
        "${pkgs.iw}/bin/iw dev wlp194s0 interface add mon0 type monitor"
        "${pkgs.iproute2}/bin/ip link set ap0 up"
        "${pkgs.iproute2}/bin/ip link set mon0 up"
      ];
      ExecStop = [
        "-${pkgs.iproute2}/bin/ip link set mon0 down"
        "-${pkgs.iproute2}/bin/ip link set ap0 down"
        "-${pkgs.iw}/bin/iw dev mon0 del"
        "-${pkgs.iw}/bin/iw dev ap0 del"
      ];
    };
  };
}
