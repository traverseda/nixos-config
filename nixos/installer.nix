{ inputs, outputs, lib, config, pkgs, hostname, specialArgs, options, ... }: {
  imports = [
  ];
  # hardware.enableAllHardware = true;
  console.packages = options.console.packages.default ++ [ pkgs.terminus_font ];

  # Add Memtest86+ to the CD.
  boot.loader.grub.memtest86.enable = true;

  swapDevices = lib.mkImageMediaOverride [ ];
  fileSystems = lib.mkImageMediaOverride config.lib.isoFileSystems;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  environment.systemPackages = [
    # Calamares for graphical installation
    pkgs.libsForQt5.kpmcore
    pkgs.calamares-nixos
    pkgs.calamares-nixos-extensions
    pkgs.calamares-nixos-autostart
  ];

}
