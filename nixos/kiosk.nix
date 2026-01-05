{ inputs, outputs, lib, config, pkgs, hostname, specialArgs, ... }:

let
  kioskUrl = specialArgs.kioskUrl or "http://localhost:8123";
  enableDarkMode = specialArgs.enableDarkMode or true;
  dailyRestart = specialArgs.dailyRestart or true;
  dimTimeout = specialArgs.dimTimeout or 300;
  dimBrightness = specialArgs.dimBrightness or "10%";

  chromiumKiosk = pkgs.writeShellScript "chromium-kiosk" ''
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
  '';

  swayIdleCmd = pkgs.writeShellScript "swayidle-kiosk" ''
    exec ${pkgs.swayidle}/bin/swayidle -w \
      timeout ${toString dimTimeout} '${pkgs.brightnessctl}/bin/brightnessctl set ${dimBrightness}' \
      resume '${pkgs.brightnessctl}/bin/brightnessctl set 100%' \
      timeout ${toString (dimTimeout + 60)} 'swaymsg "output * dpms off"' \
      resume 'swaymsg "output * dpms on"'
  '';

  swayConfig = pkgs.writeText "sway-kiosk-config" ''
    output eDP-1 transform 0
    default_border pixel 2

    exec ${pkgs.waybar}/bin/waybar
    exec ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator
    exec ${swayIdleCmd}
    exec ${chromiumKiosk}

    for_window [app_id="chromium-browser"] move to workspace 1
    bindsym Ctrl+Shift+r exec ${pkgs.procps}/bin/pkill -u kiosk chromium
  '';

  browserRestartScript = pkgs.writeShellScript "restart-browser" ''
    ${pkgs.procps}/bin/pkill -u kiosk chromium || true
  '';

in
{
  hardware.bluetooth.enable = false;
  hardware.bluetooth.powerOnBoot = false;
  hardware.graphics.enable = true;

  system.autoUpgrade.operation = "boot";

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  users.users.kiosk = {
    isNormalUser = true;
    extraGroups = [ "video" "networkmanager" ];
  };

  # Add udev rules for backlight control
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", KERNEL=="intel_backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';

  networking.networkmanager.enable = true;

  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.sway}/bin/sway --config ${swayConfig}";
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

  environment.etc."xdg/waybar/config".text = builtins.toJSON {
    layer = "top";
    position = "bottom";
    height = 40;
    modules-left = [ "custom/launcher" ];
    modules-center = [];
    modules-right = [ "network" "pulseaudio" "clock" ];

    "custom/launcher" = {
      format = " Apps";
      on-click = "${pkgs.wofi}/bin/wofi --show drun";
      tooltip = false;
    };

    network = {
      format-wifi = " {essid}";
      format-disconnected = "⚠ Disconnected";
      on-click = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
    };

    pulseaudio = {
      format = "{icon} {volume}%";
      format-icons = [ "" "" "" ];
      on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
    };

    clock = {
      format = "{:%H:%M}";
    };
  };

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

  systemd.user.services.kiosk-browser = {
    description = "Kiosk Chromium browser";
    wantedBy = [ "sway-session.target" ];
    after = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = chromiumKiosk;
      Restart = "always";
      RestartSec = "3s";
      TimeoutStartSec = "30s";
    };

    environment = {
      WAYLAND_DISPLAY = "wayland-1";
      XDG_RUNTIME_DIR = "/run/user/1000";
    };
  };

  systemd.timers.restart-kiosk-browser = lib.mkIf dailyRestart {
    description = "Daily restart of kiosk browser";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:00:00";
      Persistent = true;
    };
  };

  systemd.services.restart-kiosk-browser = lib.mkIf dailyRestart {
    description = "Restart kiosk browser";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = browserRestartScript;
    };
  };
}
