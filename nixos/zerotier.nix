{ config, pkgs, lib, options, ... }:

let
  privateZeroTierInterfaces = [ "ztmwri5sbj" ]; # ZT NET INTERFACE 
in {

  networking.firewall.trustedInterfaces = privateZeroTierInterfaces; # TRUST VPN ONLY
  
  services.avahi.enable = true;
  services.avahi.allowInterfaces = privateZeroTierInterfaces; # ONLY BROADCAST ON VPN
  services.avahi.ipv6 = true;
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;
  services.avahi.publish.addresses = true;
  services.avahi.publish.domain = true;
  services.avahi.nssmdns4 = true;
  services.avahi.publish.workstation = true; # ADDED TO DESKTOP MACHINES

  services.zerotierone.enable = true;

  #Don't join zerotier if I'm testing in a VM
  services.zerotierone.joinNetworks = lib.optionals (!options.virtualisation ? qemu) [ "e04fa485ed2a4dc4" ];
}
