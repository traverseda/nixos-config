{ inputs, outputs, lib, config, pkgs, hostname, specialArgs, ... }:

let
  kioskUrl = specialArgs.kioskUrl or "http://192.168.0.11:8123";
  enableDarkMode = specialArgs.enableDarkMode or true;
  dailyRestart = specialArgs.dailyRestart or true;
  dimTimeout = specialArgs.dimTimeout or 300; # seconds before dimming
  dimBrightness = specialArgs.dimBrightness or "10%";
in
{
  networking.firewall.enable = false;

  users.users.traverseda = {
    extraGroups = [ ];
  };

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  hardware.graphics.enable = true;

  system.autoUpgrade = {
    operation = "boot";
  };

  # Sway configuration
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # Kiosk user
  users.users.kiosk = {
    isNormalUser = true;
    extraGroups = [ "video" "networkmanager" ];
  };

  # Enable NetworkManager for WiFi
  networking.networkmanager.enable = true;

  # Auto-login and start Sway
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd ${pkgs.sway}/bin/sway";
        user = "kiosk";
      };
      initial_session = {
        command = "${pkgs.sway}/bin/sway";
        user = "kiosk";
      };
    };
  };

  # Install useful packages for kiosk
  environment.systemPackages = with pkgs; [
    networkmanagerapplet
    pavucontrol
    wofi
    kitty
    waybar
    brightnessctl
    swayidle
  ];

  # Sway config for kiosk user
  environment.etc."sway/config.d/kiosk.conf".text = ''
    # Output configuration with rotation
    output eDP-1 transform 90

    # Keep window decorations for flexibility
    default_border pixel 2

    # Start waybar
    exec ${pkgs.waybar}/bin/waybar

    # Start applications
    exec ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator
    exec ${pkgs.chromium}/bin/chromium ${lib.optionalString enableDarkMode "--force-dark-mode --enable-features=WebUIDarkMode"} --start-fullscreen --enable-features=UseOzonePlatform --ozone-platform=wayland ${kioskUrl}

    # Idle management with dimming
    exec ${pkgs.swayidle}/bin/swayidle -w \
      timeout ${toString dimTimeout} '${pkgs.brightnessctl}/bin/brightnessctl set ${dimBrightness}' \
      resume '${pkgs.brightnessctl}/bin/brightnessctl set 100%' \
      timeout ${toString (dimTimeout + 60)} 'swaymsg "output * dpms off"' \
      resume 'swaymsg "output * dpms on"'

    # Touch device configuration
    input type:touch {
      events enabled
    }
  '';

  # Waybar configuration
  environment.etc."xdg/waybar/config".text = ''
    {
      "layer": "top",
      "position": "bottom",
      "height": 40,
      "modules-left": ["custom/launcher"],
      "modules-center": [],
      "modules-right": ["network", "pulseaudio", "clock"],

      "custom/launcher": {
        "format": " Apps",
        "on-click": "${pkgs.wofi}/bin/wofi --show drun",
        "tooltip": false
      },

      "network": {
        "format-wifi": " {essid}",
        "format-disconnected": "⚠ Disconnected",
        "on-click": "${pkgs.networkmanagerapplet}/bin/nm-connection-editor"
      },

      "pulseaudio": {
        "format": "{icon} {volume}%",
        "format-icons": ["", "", ""],
        "on-click": "${pkgs.pavucontrol}/bin/pavucontrol"
      },

      "clock": {
        "format": "{:%H:%M}"
      }
    }
  '';

  # Waybar styling
  environment.etc."xdg/waybar/style.css".text = ''
    * {
      font-family: monospace;
      font-size: 14px;
    }

    window#waybar {
      background-color: rgba(30, 30, 30, 0.9);
      color: #ffffff;
    }

    #custom-launcher {
      background-color: #5294e2;
      color: #ffffff;
      padding: 0 15px;
      margin: 5px;
      border-radius: 5px;
    }

    #custom-launcher:hover {
      background-color: #6aa6f8;
    }

    #network, #pulseaudio, #clock {
      padding: 0 10px;
      margin: 5px;
    }
  '';

  # Systemd service to restart Sway daily (optional)
  systemd.services.restart-sway-kiosk = lib.mkIf dailyRestart {
    description = "Restart Sway kiosk session";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/loginctl terminate-user kiosk";
    };
  };

  systemd.timers.restart-sway-kiosk = lib.mkIf dailyRestart {
    description = "Daily restart of Sway kiosk";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };
}
