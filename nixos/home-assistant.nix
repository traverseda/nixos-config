{ inputs, outputs, lib, config, pkgs, hostname, specialArgs, ... }:
{

  services.home-assistant = {
    enable = true;
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
        http = {};
        history = {};
    };
  };

  networking.firewall.allowedTCPPorts = [ 8123 ];

  services.node-red = {
      enable = true;
      withNpmAndGcc = true;
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
      export CHROMIUM_FLAGS="--touch-devices=10 --enable-pinch" 
      exec ${pkgs.chromium}/bin/chromium  --force-dark-mode --kiosk http://127.0.0.1:8123
      ''}/bin/start-cage-app";
  };
  users.users.kiosk = {
    isNormalUser = true;
  };

}
