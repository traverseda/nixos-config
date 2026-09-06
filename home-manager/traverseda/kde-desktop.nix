
{ inputs, outputs, lib, config, pkgs, ... }: let
  qt6Pkgs = pkgs.qt6;
in
{
  imports = [
    inputs.plasma-manager.homeModules.plasma-manager
    # inputs.stylix.homeModules.stylix
  ];
  # stylix = {
  #   enable = true;
  #   base16Scheme = "${builtins.path {path = ./themes/blue_and_gold.yaml; }}";
  #   # base16Scheme = "${pkgs.base16-schemes}/share/themes/atelier-estuary.yaml";
  #   # base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-city-dark.yaml";
  #   image = "${builtins.path { path = ../../wallpapers/halifax_waterfront_night_rain.jpg; }}";
  #   # targets.firefox.firefoxGnomeTheme.enable = false;
  # };
  home.sessionVariables = {
    LC_ALL = "en_US.UTF-8";
  };

  # services.opensnitch-ui.enable = true;

  programs.plasma = {
    enable = true;
    kscreenlocker.appearance.wallpaperSlideShow.path = "${builtins.path { path = ../../wallpapers; }}";
    workspace.wallpaperSlideShow.path = "${builtins.path { path = ../../wallpapers; }}";

    # The wallpaper slideshow is applied via a qdbus call to plasmashell,
    # fired from an autostart .desktop entry at login. That call can race
    # plasmashell's D-Bus interface coming up; when it does, the call fails
    # silently but the runner script (dash, not bash) still records the run
    # as successful and never retries. Wait for plasmashell to be reachable
    # over D-Bus before letting the wallpaper script run.
    startup.desktopScript."wallpaper_slideshow".preCommands = ''
      for i in $(seq 1 60); do
        qdbus org.kde.plasmashell >/dev/null 2>&1 && break
        sleep 1
      done
    '';

    shortcuts = {
      "services/org.kde.konsole.desktop"."_launch" = ["Meta+Return" "Ctrl+Alt+T"];
      "kwin"."Window Close" = ["Meta+Shift+C" "Alt+F4"];
      "kwin"."Cube" = "Meta+C";
    };
    shortcuts.plasmashell = {
      "activate task manager entry 1" = "";
      "activate task manager entry 2" = "";
      "activate task manager entry 3" = "";
      "activate task manager entry 4" = "";
      "activate task manager entry 5" = "";
      "activate task manager entry 6" = "";
      "activate task manager entry 7" = "";
      "activate task manager entry 8" = "";
      "activate task manager entry 9" = "";
    };
    shortcuts.kwin = {
      "Switch to Desktop 1" = "Meta+1"; 
      "Window to Desktop 1" = "Meta+!";
      "Switch to Desktop 2" = "Meta+2"; 
      "Window to Desktop 2" = "Meta+@";
      "Switch to Desktop 3" = "Meta+3"; 
      "Window to Desktop 3" = "Meta+#";
      "Switch to Desktop 4" = "Meta+4"; 
      "Window to Desktop 4" = "Meta+$";
      "Switch to Desktop 5" = "Meta+5"; 
      "Window to Desktop 5" = "Meta+%";
      "Switch to Desktop 6" = "Meta+6"; 
      "Window to Desktop 6" = "Meta+^";
      "Switch to Desktop 7" = "Meta+7"; 
      "Window to Desktop 7" = "Meta+&";
      "Switch to Desktop 8" = "Meta+8"; 
      "Window to Desktop 8" = "Meta+*";
      "Switch to Desktop 9" = "Meta+9"; 
      "Window to Desktop 9" = "Meta+(";
      "Switch to Desktop 10" = "Meta+0"; 
      "Window to Desktop 10" = "Meta+)";
    };
    configFile = {
      "kwinrc"."Desktops"."Number"."value" = 10;
      "kwinrc"."Desktops"."Rows"."value" = 2;
      "kwinrc"."Plugins"."cubeEnabled" = true;
      "kwinrc"."Windows"."FocusPolicy" = "FocusFollowsMouse";
      # Baloo indexes/extracts content across all of $HOME by default with
      # no awareness of things like Nextcloud sync churn, Wine prefixes, or
      # Rust target/ dirs. Not used for search here, so just turn it off.
      "baloofilerc"."Basic Settings"."Indexing-Enabled" = false;
    };

    panels = [
      {
        location = "bottom";
        widgets = [
          "org.kde.plasma.kickoff"
          "org.kde.plasma.pager"
          "org.kde.plasma.taskmanager"
          "org.kde.plasma.marginsseparator"
          {
            name = "org.kde.plasma.systemmonitor";
            config = {
              Appearance = {
                chartFace = "org.kde.ksysguard.barchart";
                title = "CPU Usage";
              };
              Sensors.highPrioritySensorIds = ''["cpu/all/user","cpu/all/system","cpu/all/wait"]'';
              SensorColors = {
                "cpu/all/user" = "103,197,247";
                "cpu/all/system" = "247,103,103";
                "cpu/all/wait" = "247,206,103";
              };
              "org.kde.ksysguard.barchart/General" = {
                barChartStacked = true;
                rangeAuto = false;
                rangeFrom = 0;
                rangeTo = 100;
              };
            };
          }
          {
            name = "org.kde.plasma.systemmonitor";
            config = {
              Appearance = {
                chartFace = "org.kde.ksysguard.barchart";
                title = "CPU Frequency";
              };
              Sensors.highPrioritySensorIds = ''["cpu/all/averageFrequency"]'';
              SensorColors."cpu/all/averageFrequency" = "172,103,247";
              "org.kde.ksysguard.barchart/General" = {
                rangeAuto = false;
                rangeFrom = 0;
                rangeTo = 5010;
              };
            };
          }
          {
            name = "org.kde.plasma.systemmonitor";
            config = {
              Appearance = {
                chartFace = "org.kde.ksysguard.barchart";
                title = "GPU & Memory";
              };
              Sensors.highPrioritySensorIds = ''["gpu/all/usage","memory/physical/usedPercent"]'';
              SensorColors = {
                "gpu/all/usage" = "103,247,137";
                "memory/physical/usedPercent" = "247,103,228";
              };
              SensorLabels = {
                "gpu/all/usage" = "GPU usage";
                "memory/physical/usedPercent" = "Memory Usage";
              };
              "org.kde.ksysguard.barchart/General" = {
                rangeAuto = false;
                rangeFrom = 0;
                rangeTo = 100;
              };
            };
          }
          "org.kde.plasma.systemtray"
          {
            name = "org.kde.plasma.digitalclock";
            config = {
              Appearance.fontWeight = 400;
            };
          }
          "org.kde.plasma.showdesktop"
        ];
      }
    ];
  };
}
