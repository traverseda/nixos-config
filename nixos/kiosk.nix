{ inputs, outputs, lib, config, pkgs, hostname, specialArgs, ... }:

let
  kioskUrl = specialArgs.kioskUrl or "http://192.168.0.11:8123";
  enableDarkMode = specialArgs.enableDarkMode or true;
  dailyRestart = specialArgs.dailyRestart or true;
  dimTimeout = specialArgs.dimTimeout or 300;
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

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  users.users.kiosk = {
    isNormalUser = true;
    extraGroups = [ "video" "networkmanager" ];
  };

  networking.networkmanager.enable = true;

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

  environment.systemPackages = with pkgs; [
    networkmanagerapplet
    pavucontrol
    wofi
    kitty
    waybar
    brightnessctl
    swayidle
  ];

  environment.etc."sway/config.d/kiosk.conf".text = ''
    output eDP-1 transform 0
    default_border pixel 2

    exec ${pkgs.waybar}/bin/waybar
    exec ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator

    # Improved Chrome flags for kiosk-like experience
    exec ${pkgs.chromium}/bin/chromium \
      --app=${kioskUrl} \
      ${lib.optionalString enableDarkMode "--force-dark-mode --enable-features=WebUIDarkMode"} \
      --enable-features=UseOzonePlatform \
      --ozone-platform=wayland \
      --disable-infobars \
      --disable-session-crashed-bubble \
      --disable-restore-session-state \
      --disable-features=TranslateUI \
      --disable-component-update \
      --no-first-run \
      --noerrdialogs \
      --disable-pinch \
      --overscroll-history-navigation=0 \
      --disable-features=OverlayScrollbar

    exec ${pkgs.swayidle}/bin/swayidle -w \
      timeout ${toString dimTimeout} '${pkgs.brightnessctl}/bin/brightnessctl set ${dimBrightness}' \
      resume '${pkgs.brightnessctl}/bin/brightnessctl set 100%' \
      timeout ${toString (dimTimeout + 60)} 'swaymsg "output * dpms off"' \
      resume 'swaymsg "output * dpms on"'

    input type:touch {
      events enabled
    }
  '';

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
