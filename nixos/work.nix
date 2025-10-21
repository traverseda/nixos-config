{
  config,
  pkgs,
  # system,
  inputs,
  #  lib,
  #  ros,
  ...
}:

{
  virtualisation.virtualbox.host.enable = true;

  users.extraGroups.vboxusers.members = [ "traverseda" ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.binfmt.preferStaticEmulators = true;

  security.wrappers = {
    firejail = {
      source = "${pkgs.firejail.out}/bin/firejail";
    };
  };

  programs.firejail = {
    enable = true;
  };
  # programs.sniffnet.enable = true;
  programs.fcast-receiver = {
    enable = true;
    openFirewall = true;
  };

  # services.kubo = {
  #   enable = true;
  #   autoMount = true;
  #   localDiscovery = true;
  # };
  # users.users.traverseda.extraGroups = [ config.services.kubo.group ];

  users.groups.libvirtd.members = ["traverseda"];

  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  environment.systemPackages = [
    pkgs.qemu
    # pkgs.virt-manager-qt
    pkgs.unstable.qgroundcontrol
    pkgs.networkmanager-iodine
    pkgs.squashfsTools
    pkgs.parted
    pkgs.vscode
    pkgs.openterface-qt
    pkgs.sshfs
    pkgs.stdenv
    pkgs.gcc
    pkgs.rustc
    pkgs.cargo
    pkgs.zig
    pkgs.kdePackages.kompare
    pkgs.unstable.distrobox
    pkgs.element-desktop
    pkgs.act
    pkgs.uv

    pkgs.opencpn # boats charts
    pkgs.gsettings-desktop-schemas

    pkgs.freerdp3
    #Github cli
    pkgs.gh
    # inputs.winapps.packages.x86_64-linux.winapps
    # inputs.winapps.packages.x86_64-linux.winapps-launcher

    # pkgs.logseq
    (pkgs.writeShellScriptBin "python" ''
      export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
      exec ${pkgs.python3}/bin/python "$@"
    '')

    (pkgs.writeShellScriptBin "poetry" ''
      export LD_LIBRARY_PATH=$NIX_LD_LIBRARY_PATH
      exec ${pkgs.poetry}/bin/poetry "$@"
    '')
  ];


  programs.nix-ld = {
    enable = true;
    #Include libstdc++ in the nix-ld profile
    libraries = [
      pkgs.unstable.openterface-qt
      pkgs.stdenv.cc.cc
      pkgs.zlib
      pkgs.fuse3
      pkgs.icu
      pkgs.nss
      pkgs.openssl
      pkgs.curl
      pkgs.expat
      pkgs.xorg.libX11
      pkgs.vulkan-headers
      pkgs.vulkan-loader
      pkgs.vulkan-tools
      pkgs.kdePackages.full
      pkgs.qt5.full
      pkgs.libxkbcommon
      pkgs.mesa
      pkgs.glib
      pkgs.fontconfig
      pkgs.freetype
    ];
  };
  services.envfs = {
    enable = true;
  };
}
