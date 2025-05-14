{ pkgs, config, lib, ... }:

{
  services.udev.extraRules = ''
    # Openterface Mini-KVM rules
    SUBSYSTEM=="usb", ATTRS{idVendor}=="534d", ATTRS{idProduct}=="2109", TAG+="uaccess"
    SUBSYSTEM=="usb", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", TAG+="uaccess"
  '';
}
