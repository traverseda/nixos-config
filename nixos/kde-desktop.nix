{ inputs, outputs, lib, config, pkgs, hostname, specialArgs, options, ... }:

{
  imports = [
    #    ./misc/dslr-webcam.nix
    ./misc/wifi-multiplex.nix
  ];

  #Enable lightdm with networkmanger management in our login screen
  services.xserver.enable = true;
  # services.xserver.displayManager.lightdm.enable = true;
  # services.xserver.displayManager.lightdm.greeters.gtk.enable = true;
  # services.xserver.displayManager.lightdm.greeters.gtk.indicators = [ 
  #   "~host" "~spacer" "~clock" "~spacer" 
  #   "${pkgs.networkmanagerapplet}/bin/nm-applet"
  #   "~session"
  #   # "~language"
  #   "~a11y" "~power"
  # ];
  # users.users.lightdm = {
  #   isSystemUser = true;
  #   extraGroups = [ "networkmanager" ];
  # };


  # Enable the KDE Desktop Environment.
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;


  services.displayManager.defaultSession = "plasma";
  services.displayManager = {
    autoLogin.enable = lib.mkDefault false;
  };

  services.flatpak.enable = true;

  environment.etc = {
    "flatpak/remotes.d/flathub.flatpakrepo".source = pkgs.fetchurl {
      url = "https://dl.flathub.org/repo/flathub.flatpakrepo";
      hash = "sha256-M3HdJQ5h2eFjNjAHP+/aFTzUQm9y9K+gwzc64uj+oDo="
      ;
    };
  };

  services.packagekit.enable = true;
  services.fwupd.enable = true;

  boot.plymouth = {
    enable = true;
    themePackages = with pkgs; [ (adi1090x-plymouth-themes.override { selected_themes = [ "hexagon_2" ]; }) ];
    theme = "hexagon_2";
  };

  hardware.graphics.enable = true;

  services.fprintd.enable = true;
  services.printing.enable = true;
  programs.kdeconnect.enable = true;

  #Enable flatpak repo by default for all users
  systemd.services.flatpak-repo = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.flatpak ];
    script = ''
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    '';
  };

  programs.partition-manager.enable = true;

  environment.systemPackages = [
    pkgs.krfb
    pkgs.krdc
    pkgs.kdePackages.kio-fuse
    pkgs.kdePackages.kio-extras
    pkgs.discover
    pkgs.libreoffice-qt
    pkgs.filelight
    pkgs.hunspell
    pkgs.hunspellDicts.en_CA
    pkgs.hunspellDicts.en_US
    pkgs.thunderbird
    pkgs.inkscape
    pkgs.gimp
    pkgs.krita
    pkgs.nextcloud-client
    pkgs.iw
    pkgs.vlc
    pkgs.signal-desktop
    pkgs.anki
    pkgs.kitty
    pkgs.koreader
  ];

  fonts.packages = [
    pkgs.noto-fonts-cjk-sans
  ];

  programs.dconf.enable = true;

  programs.firefox = {
    enable = true;
    policies = {
      DisableTelemetry = true;
      DisableFirefoxStudies = true;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
      DisablePocket = true;
      OverrideFirstRunPage = "";
      OverridePostUpdatePage = "";
      DontCheckDefaultBrowser = true;
      Preferences = {
        "widget.use-xdg-desktop-portal.file-picker" = 1;
        "widget.use-xdg-desktop-portal.mime-handler" = 1;
      };
      ExtensionSettings = {
        "*".installation_mode = "allowed";
        # uBlock Origin:
        "uBlock0@raymondhill.net" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
          installation_mode = "normal_installed";
        };
      };
    };
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  home-manager = {
    extraSpecialArgs = { inherit inputs outputs; };
    backupFileExtension = ".bak";
    users = {
      traverseda = import ../home-manager/traverseda/kde-desktop.nix;
    };
  };

  #Enable support for my logitech bluetooth peripherals
  hardware.logitech.wireless.enable = true;
  hardware.logitech.wireless.enableGraphical = true;

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    raopOpenFirewall = true;

    extraConfig.pipewire = {
      "10-airplay" = {
        "context.modules" = [
          {
            name = "libpipewire-module-raop-discover";

            # increase the buffer size if you get dropouts/glitches
            # args = {
            #   "raop.latency.ms" = 500;
            # };
          }
        ];
      };
    };
  };

  system.stateVersion = "23.05";
}
