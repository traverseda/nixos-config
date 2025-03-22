{ inputs, outputs, lib, config, pkgs, hostname, specialArgs, ... }:
{
  networking.firewall.enable = false;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.home-assistant = {
    enable = false;
    extraComponents = [
      "default_config"
      "tplink"
      "met"
      "esphome"
      "etherscan"
      "recorder"
      "history"
      "history_stats"
      "zha"
      "system_health"
      "ibeacon"
      "govee_ble"
      "systemmonitor"
      "dialogflow"
      "automation"
      "device_automation"
      "androidtv"
      "rhasspy"
      "scene"
      "script"
      "openweathermap"
    ];
    configWritable = true;
    config = {
      homeassistant = {
        name = "${hostname}";
        unit_system = "metric";
        time_zone = "America/Halifax";
        auth_providers = [
          {
            type = "trusted_networks";
            trusted_networks = [
              "192.168.0.0/24"
              "127.0.0.1"
            ];
            allow_bypass_login = true;
          }
          {
            type = "homeassistant";
          }
        ];
      };
      automation = "!include automations.yaml";
      scene = "!include scenes.yaml";
      frontend = {
        themes = "!include_dir_merge_named themes";
      };
      http = { };
      history = { };
    };
  };

  networking.firewall.allowedTCPPorts = [ 8123 ];

  system.autoUpgrade = {
    operation = "boot";
  };

  services.node-red = {
    enable = false;
    withNpmAndGcc = true;
    openFirewall = true;
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = false;
    # other Nginx options
    virtualHosts."hearth.local" = {
      enableACME = false;
      forceSSL = false;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8123";
        proxyWebsockets = true; # needed if you need to use WebSocket
      };
    };
  };

  services.cron.enable = true;

  programs.fcast-receiver = {
    enable = true;
    openFirewall = true;
  };

  #Break touchscreen support
  #${pkgs.wlr-randr}/bin/wlr-randr --output eDP-1 --transform 90 # Adjust command as needed

  services.cage = {
    enable = true;
    user = "kiosk";
    extraArguments = [ "-d" "-s" ];
    program = "${pkgs.writeScriptBin "start-cage-app" ''
      #!/usr/bin/env bash
      exec ${pkgs.fcast-receiver}/bin/fcast-receiver --enable-features=UseOzonePlatform --ozone-platform=wayland --no-main-window &
      export CHROMIUM_FLAGS="--touch-devices=10 --enable-pinch"
      exec ${pkgs.chromium}/bin/chromium  --force-dark-mode --kiosk http://127.0.0.1:8123
      ''}/bin/start-cage-app";
  };
  systemd.services."cage-tty1".serviceConfig = {
    Restart = "always";
    RestartSec="5";
    StartLimitIntervalSec="0";
    RestartForceExitStatus="0 SIGTERM SIGINT SIGUSR1 SIGUSR2";
  };

  users.users.kiosk = {
    isNormalUser = true;
  };

}
