{
  #  config,
  pkgs
, #  lib,
  #  ros,
  ...
}:

{
  virtualisation.virtualbox.host.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

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
  programs.sniffnet.enable = true;

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
      pkgs.devenv
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

  environment.systemPackages = [
    pkgs.qemu
    pkgs.unstable.qgroundcontrol
    pkgs.networkmanager-iodine
    pkgs.squashfsTools
    pkgs.parted
    pkgs.vscode
    pkgs.sshfs
    pkgs.stdenv
    pkgs.gcc
    pkgs.rustc
    pkgs.cargo
    pkgs.zig
    pkgs.kompare
    pkgs.unstable.distrobox
    pkgs.element-desktop
    pkgs.act
    pkgs.uv

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
}

