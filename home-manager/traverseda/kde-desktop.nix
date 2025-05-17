
{ inputs, outputs, lib, config, pkgs, ... }: let
  qt6Pkgs = pkgs.qt6;
in
{
  imports = [
    inputs.plasma-manager.homeManagerModules.plasma-manager
    inputs.stylix.homeManagerModules.stylix
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

  programs.plasma = {
    enable = true;
    kscreenlocker.appearance.wallpaperSlideShow.path = "${builtins.path { path = ../../wallpapers; }}";
    workspace.wallpaperSlideShow.path = "${builtins.path { path = ../../wallpapers; }}";

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
    };
  };
}
