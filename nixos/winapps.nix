{
  config,
  pkgs,
  lib,
  winapps,
  ...
}: let
  cfg = config.services.winapps;

  podman-wrapper = pkgs.writeShellScriptBin "podman" ''
    exec ${config.environment.systemPackages}/bin/podman-distrobox "$@"
  '';

  winapps-container-setup = pkgs.writeShellScriptBin "winapps-container-setup" ''
    exec ${lib.getExe podman-wrapper} compose -f "$WINAPPS_DATA/compose.yaml" up -d
  '';
in {
  options = {
    services.winapps.enable = lib.mkEnableOption "WinApps integration";

    services.winapps.rdpScaling = lib.mkOption {
      type = lib.types.int;
      default = 140;
      description = "Display scaling factor for Windows RDP connections.";
    };

    services.winapps.windowsHostIP = lib.mkOption {
      type = lib.types.str;
      default = "192.168.122.1";
      description = "Windows VM/RDP host IP address.";
    };

    services.winapps.windowsUser = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Windows username for RDP connections.";
    };

    services.winapps.windowsPassword = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Windows password for RDP connections.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      winapps.packages.${pkgs.system}.winapps
      winapps.packages.${pkgs.system}.winapps-launcher
      podman-wrapper
    ];

    environment.sessionVariables = {
      WINAPPS_CONTAINER_MANAGER = "${lib.getExe podman-wrapper}";
      WINAPPS_DATA = "/opt/winapps";
    };

    environment.etc."winapps/winapps.conf".text =
      "RDP_SCALING=${toString cfg.rdpScaling}\n"
      + "WAFLAVOR=podman\n"
      + "RDP_IP=${cfg.windowsHostIP}\n"
      + "WINDOWS_USER=${cfg.windowsUser}\n"
      + "WINDOWS_PASSWORD=${cfg.windowsPassword}\n";

    systemd.user.services.winapps-container = {
      description = "WinApps Podman Windows VM container";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = "${winapps-container-setup}/bin/winapps-container-setup";
      };
    };
  };
}
