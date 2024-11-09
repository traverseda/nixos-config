{
#  config,
  pkgs,
#  lib,
#  ros,
  ... }:

{
  virtualisation.virtualbox.host.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  users.extraGroups.vboxusers.members = [ "traverseda" ];
  boot.binfmt.emulatedSystems = ["aarch64-linux"];

  security.wrappers = {
    firejail = {
      source = "${pkgs.firejail.out}/bin/firejail";
    };
  };

  programs.firejail = {
    enable = true;
  };

  programs.nix-ld = {
    enable = true;
    #Include libstdc++ in the nix-ld profile
    libraries = [
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

  environment.systemPackages = [
    pkgs.qemu
    pkgs.qgroundcontrol
    pkgs.vscode
    pkgs.stdenv
    pkgs.gcc
    pkgs.rustc
    pkgs.cargo
    pkgs.zig
    pkgs.kompare
    pkgs.unstable.distrobox
    pkgs.element-desktop
    pkgs.act

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

