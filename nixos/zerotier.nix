{ config, pkgs, lib, options, ... }:

let
  privateZeroTierInterfaces = [ "zt_aura" ]; # ZT NET INTERFACE 
in {

  networking.firewall.trustedInterfaces = privateZeroTierInterfaces; # TRUST VPN ONLY

  services.avahi = {
    enable = true;
    #allowInterfaces = privateZeroTierInterfaces; # ONLY BROADCAST ON VPN
    ipv6 = true;
    publish.enable = true;
    publish.userServices = true;
    publish.addresses = true;
    publish.domain = true;
    nssmdns4 = true;
    publish.workstation = true; # ADDED TO DESKTOP MACHINES
    cacheEntriesMax = 512;
  };

  systemd.services.createDevicemap = {
    description = "Create ZeroTier devicemap file";
    before = [ "zerotierone.service" ]; # Ensure ZeroTier service has started
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      mkdir -p /var/lib/zerotier-one
      echo "e04fa485ed2a4dc4=zt_aura" > /var/lib/zerotier-one/devicemap
    '';
  };

  services.zerotierone.enable = true;

  #Don't join zerotier if I'm testing in a VM
  services.zerotierone.joinNetworks = lib.optionals (!options.virtualisation ? qemu) [ "e04fa485ed2a4dc4" ];
}
