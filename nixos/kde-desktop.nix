{ config, pkgs, lib, ... }:

{
  # Enable the KDE Desktop Environment.
  services.xserver.enable = true;
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;


  system.stateVersion = "23.05";
}
