{ config, pkgs, lib, ... }:

{
  # Enable the KDE Desktop Environment.
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  services.displayManager.defaultSession = "plasma";

  boot.plymouth.enable = true;
  boot.plymouth.theme="breeze";

  hardware.opengl.enable = true;

  services.fprintd.enable = true;
  services.printing.enable = true;

  environment.systemPackages = with pkgs; [
    pkgs.krfb
    pkgs.krdc
    pkgs.libreoffice-qt
    pkgs.filelight
    pkgs.hunspell
    pkgs.hunspellDicts.en_CA
    pkgs.hunspellDicts.en_US
    pkgs.openscad
    pkgs.inkscape
    pkgs.blender
    pkgs.gimp
    pkgs.krita
  ];

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
        };
        ExtensionSettings = {
          "*".installation_mode = "blocked"; # blocks all addons except the ones specified below
          # uBlock Origin:
          "uBlock0@raymondhill.net" = {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
            installation_mode = "normal_installed";
          };
        };
    };
  };


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
