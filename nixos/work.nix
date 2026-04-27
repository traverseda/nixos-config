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

  environment.etc.hosts.mode = "0644";

  programs.virt-manager.enable = true;

  users.groups.libvirtd.members = ["traverseda"];

  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;


  virtualisation.podman = {
    enable = true;
    dockerCompat = false;
    defaultNetwork.settings.dns_enabled = true;
  };


  # Auto-prune for distrobox-specific podman storage
  systemd.user.timers."podman-distrobox-prune" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };

  systemd.user.services."podman-distrobox-prune" = {
    description = "Prune unused distrobox podman resources";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.podman}/bin/podman --root %h/.local/share/distrobox-podman/storage --runroot /run/user/%U/distrobox-podman system prune -f";
    };
  };


  environment.sessionVariables = {
    DBX_CONTAINER_MANAGER = "/run/current-system/sw/bin/podman-distrobox";
  };


  environment.systemPackages = [
    pkgs.podman
    pkgs.unstable.distrobox

    # Wrapper that runs podman with isolated storage for distrobox
    (pkgs.writeShellScriptBin "podman-distrobox" ''
      exec ${pkgs.podman}/bin/podman \
        --root "$HOME/.local/share/distrobox-podman/storage" \
        --runroot "$XDG_RUNTIME_DIR/distrobox-podman" \
        "$@"
    '')    
    pkgs.qemu
    pkgs.unstable.qgroundcontrol
    pkgs.networkmanager-iodine
    pkgs.squashfsTools
    pkgs.parted
    pkgs.openterface-qt
    pkgs.sshfs
    pkgs.stdenv
    pkgs.gcc
    pkgs.zig
    pkgs.kdePackages.kompare
    pkgs.unstable.distrobox
    pkgs.element-desktop
    pkgs.act
    pkgs.uv
    pkgs.python3
    pkgs.py-spy #Flamegraph profiling


    pkgs.rustc
    pkgs.cargo
    pkgs.rust-analyzer
    pkgs.rustfmt
    pkgs.clippy

    pkgs.gsettings-desktop-schemas

    pkgs.freerdp
    #Github cli
    pkgs.gh
    
    pkgs.playwright

    pkgs.anytype #notes


    (pkgs.vscode.fhsWithPackages (ps: with ps; [
      stdenv.cc.cc.lib
    ]))

  ];


  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  environment.sessionVariables = {
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright.browsers}";
  };


  programs.nix-ld = {
    enable = true;
    #Include libstdc++ in the nix-ld profile
    libraries = [
      pkgs.stdenv.cc.cc
      # pkgs.zlib
      pkgs.fuse3
      # pkgs.icu
      # pkgs.nss
      # pkgs.openssl
      # pkgs.curl
      # pkgs.expat
      # pkgs.xorg.libX11
      # pkgs.vulkan-headers
      # pkgs.vulkan-loader
      # pkgs.vulkan-tools
      # pkgs.libxkbcommon
      # pkgs.mesa
      # pkgs.glib
      # pkgs.fontconfig
      # pkgs.freetype
    ];
  };
  services.envfs = {
    enable = true;
  };
}
