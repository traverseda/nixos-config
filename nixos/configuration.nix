# This is your system's configuration file.
# Use this to configure your system environment (it replaces /etc/nixos/configuration.nix)
{ inputs, outputs, lib, config, pkgs, hostname, specialArgs, options, ... }: {
  # You can import other NixOS modules here
  imports = [
    # If you want to use modules your own flake exports (from modules/nixos):
    # outputs.nixosModules.example

    # Or modules from other flakes (such as nixos-hardware):
    # inputs.hardware.nixosModules.common-cpu-amd
    # inputs.hardware.nixosModules.common-ssd

    # You can also split up your configuration and import pieces of it here:
    # ./users.nix

    # Import your generated (nixos-generate-config) hardware configuration
    ./hardware/${hostname}.nix
    inputs.home-manager.nixosModules.home-manager
    ./misc/openinterface-udev.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications
      outputs.overlays.unstable-packages

      # You can also add overlays exported from other flakes:
      # neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
    };
  };


  networking.hostName = hostname; # Define your hostname.
  networking.networkmanager.enable = true;
  nix.settings.trusted-users = [ "root" "traverseda" "logic11" ];
  boot.tmp.cleanOnBoot = true;

  services.davfs2.enable = true;
  # zramSwap.enable = true;

  virtualisation.vmVariant = {
    # following configuration is added only when building VM with build-vm
    virtualisation.cores = 4;
    virtualisation.memorySize = 4096;
  };

  #Fix various minor ADB issues
  services.udev.packages = [
    pkgs.android-udev-rules
  ];


  i18n.supportedLocales = [
    "C.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
  ];
  i18n.defaultLocale = "en_US.UTF-8";

  # This will add each flake input as a registry
  # To make nix3 commands consistent with your flake
  nix.registry = (lib.mapAttrs (_: flake: { inherit flake; })) ((lib.filterAttrs (_: lib.isType "flake")) inputs);

  # This will additionally add your inputs to the system's legacy channels
  # Making legacy nix commands consistent as well, awesome!
  nix.nixPath = [ "/etc/nix/path" ];
  environment.etc =
    lib.mapAttrs'
      (name: value: {
        name = "nix/path/${name}";
        value.source = value.flake;
      })
      config.nix.registry;

  nix.settings = {
    # Enable flakes and new 'nix' command
    experimental-features = "nix-command flakes";
    # Enable cross-compilation to aarch64-linux (using mkDefault to avoid conflict with binfmt)
    extra-platforms = config.boot.binfmt.emulatedSystems;
  };

  #Deduplicate nix store on a timer
  nix.optimise.automatic = true;

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    qt6.qtmultimedia
    qt6.full
    exfat
    pkgs.duc
    pkgs.glibcLocales
    pkgs.exfatprogs
    pkgs.mosh
    pkgs.htop
    pkgs.git
    pkgs.git-lfs
    pkgs.usbutils
    pkgs.pciutils
    pkgs.lsof
    pkgs.p7zip
    pkgs.atool
    pkgs.comma
    pkgs.home-manager
    pkgs.cifs-utils
    pkgs.appimage-run
    pkgs.linuxPackages.usbip
  ];

  programs.git = {
    enable = true;
    lfs.enable = true;
  };

  boot.binfmt.registrations.appimage = {
    wrapInterpreterInShell = false;
    interpreter = "${pkgs.appimage-run}/bin/appimage-run";
    recognitionType = "magic";
    offset = 0;
    mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
    magicOrExtension = ''\x7fELF....AI\x02'';
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  services.automatic-timezoned.enable = true;
  # services.power-profiles-daemon.enable = false;

  virtualisation.docker.enable = true;
  virtualisation.docker.liveRestore = false;

  # virtualisation.incus.enable = true;
  # networking.nftables.enable = true;

  #Puts fonts in /run/current-system/sw/share/X11/fonts
  fonts.fontDir.enable = true;


  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  users.users = {
    traverseda = {
      # You can set an initial password for your user.
      # If you do, you can skip setting a root password by passing '--no-root-passwd' to nixos-install.
      # Be sure to change it (using passwd) after rebooting!
      initialPassword = "changeme";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
      ];
      extraGroups = [ "wheel" "dialout" "networkmanager" "dialout" "docker" "plugdev" "vboxusers" "incus-admin" ];
    };
  };

  home-manager = {
    extraSpecialArgs = { inherit inputs outputs; };
    backupFileExtension = ".bak";
    users = {
      traverseda = import ../home-manager/traverseda/home.nix;
    };
  };

  # This setups a SSH server. Very important if you're setting up a headless system.
  # Feel free to remove if you don't need it.
  services.openssh = {
    enable = true;
    settings = {
      # Forbid root login through SSH.
      PermitRootLogin = lib.mkDefault "no";
      # Use keys only. Remove if you want to SSH using password (not recommended)
      PasswordAuthentication = true;
      AllowUsers = [ "traverseda" ];
    };
  };

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
    flake = "/home/traverseda/nixos-config/";
  };

  system.autoUpgrade = {
    enable = lib.mkDefault true;
    flake = "git+https://codeberg.org/traverseda/nixos-config#${hostname}";
    flags = [
    ];
    dates = "02:00";
    randomizedDelaySec = "45min";
  };

  # programs.nix-ld.enable = true;
  # programs.nix-ld.libraries = with pkgs; [
  # ];

  #Create ldpadmin group for printer access
  services.printing.extraFilesConf = ''
    SystemGroup root wheel lpadmin
  '';
  users.groups = {
    lpadmin = { };
  };

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  system.stateVersion = "23.05";
}
