{ inputs, outputs, lib, config, pkgs, hostname, specialArgs, options, ... }:

{
  # Enable the KDE Desktop Environment.
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.defaultSession = "plasma";
  services.displayManager = {
    autoLogin.enable = lib.mkDefault false;
  };

  services.flatpak.enable = true;
  services.packagekit.enable = true;
  services.fwupd.enable = true;

  boot.plymouth = {
    enable = true;
    themePackages = with pkgs; [ (adi1090x-plymouth-themes.override {selected_themes = [ "rings" ]; }) ];
    theme = "rings";
  };

  hardware.opengl.enable = true;

  services.fprintd.enable = true;
  services.printing.enable = true;
  programs.kdeconnect.enable = true; 

  environment.systemPackages = with pkgs; [
    pkgs.krfb
    pkgs.krdc
    pkgs.discover
    pkgs.libreoffice-qt
    pkgs.filelight
    pkgs.hunspell
    pkgs.hunspellDicts.en_CA
    pkgs.hunspellDicts.en_US
    pkgs.inkscape
    pkgs.gimp
    pkgs.krita
    pkgs.nextcloud-client
    pkgs.iw
    pkgs.vlc
  ];

programs.dconf.enable = true;

  programs.firefox = {
    enable = true;
    policies = {
        DisableTelemetry = true;
        DisableFirefoxStudies = true;
        EnableTrackingProtection = {
          Value= true;
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

  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  system.stateVersion = "23.05";
}
