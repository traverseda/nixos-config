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

  compose-path = "$WINAPPS_DATA/compose.yaml";

  winapps-container-manager = pkgs.writeShellScriptBin "winapps-container-manager" ''
    set -euo pipefail
    export PATH="${pkgs.podman}/bin:${config.environment.systemPackages}/bin:$PATH"

    if [[ $# -eq 0 ]]; then
      echo "Usage: winapps-container-manager {start|stop|restart|status|logs}"
      exit 1
    fi

    subcmd="$1"
    shift

    # Ensure the compose file exists
    if [[ ! -f "$compose-path" ]]; then
      echo "Error: WinApps container not configured yet."
      echo "Run 'winapps-setup' first to create the configuration."
      exit 1
    fi

    # Forward to podman with isolated distrobox storage
    case "$subcmd" in
      start)
        echo "Starting WinApps Windows VM container..."
        ${lib.getExe podman-wrapper} compose -f "$compose-path" up -d "$@"
        sleep 2
        ${lib.getExe podman-wrapper} ps --filter "name=RDPWindows" --format "{{.Status}}" 2>/dev/null | grep -q "Up" || echo "Container started (status may be initializing)"
        ;;
      stop)
        echo "Stopping WinApps Windows VM container..."
        ${lib.getExe podman-wrapper} compose -f "$compose-path" down
        ;;
      restart)
        echo "Restarting WinApps Windows VM container..."
        ${lib.getExe podman-wrapper} compose -f "$compose-path" restart "$@"
        ;;
      status)
        ${lib.getExe podman-wrapper} compose -f "$compose-path" ps "$@"
        ;;
      logs)
        ${lib.getExe podman-wrapper} compose -f "$compose-path" logs -f "$@"
        ;;
      *)
        echo "Unknown subcommand: $subcmd"
        exit 1
        ;;
    esac
  '';

  winapps-desktop-generator = pkgs.writeShellScriptBin "winapps-desktop-generator" ''
    set -euo pipefail

    # Generate desktop entries for Windows apps installed on the VM
    # This is idempotent and can be run any time
    if command -v winapps >/dev/null 2>&1; then
      mkdir -p "$HOME/.local/share/applications"

      # Run setup to detect Windows apps and generate entries
      # --non-interactive flag skips user prompts, making this idempotent
      winapps setup --non-interactive 2>/dev/null || {
        echo "winapps not configured yet. Run 'winapps-setup' first."
        exit 1
      }

      echo "WinApps desktop entries regenerated."
    else
      echo "winapps not installed. Deploy WinApps module first."
      exit 1
    fi
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

    services.winapps.startOnLogin = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Automatically start the Windows VM container when user logs in.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      winapps.packages.${pkgs.system}.winapps
      winapps.packages.${pkgs.system}.winapps-launcher
      winapps-container-manager
      winapps-desktop-generator
      podman-wrapper
    ];

    environment.sessionVariables = {
      WINAPPS_CONTAINER_MANAGER = "${lib.getExe podman-wrapper}";
      WINAPPS_DATA = "/opt/winapps";
    };

    # Base configuration file (overridden by user config at ~/.config/winapps/winapps.conf)
    environment.etc."winapps/winapps.conf".text =
      "RDP_SCALING=${toString cfg.rdpScaling}\n"
      + "WAFLAVOR=podman\n"
      + "RDP_IP=${cfg.windowsHostIP}\n"
      + "WINDOWS_USER=${cfg.windowsUser}\n"
      + "WINDOWS_PASSWORD=${cfg.windowsPassword}\n";

    # Systemd service to maintain the container lifecycle
    systemd.user.services.winapps-container = {
      description = "WinApps Windows VM container (managed by winapps-container-manager)";
      wantedBy = ["default.target"];
      after = ["network-online.target"];
      wants = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = "${winapps-container-manager}/bin/winapps-container-manager start";
      };
    };

    # Daily cleanup of stale resources
    systemd.user.timers.winapps-container-cleanup = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
    };

    systemd.user.services.winapps-container-cleanup = {
      description = "Cleanup stale WinApps container resources";
      wantedBy = ["default.target"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.podman}/bin/podman --root %h/.local/share/distrobox-podman/storage --runroot /run/user/%U/distrobox-podman ps --filter name=RDPWindows --format {{.Status}} 2>/dev/null | grep -q 'Up' || ${pkgs.podman}/bin/podman --root %h/.local/share/distrobox-podman/storage --runroot /run/user/%U/distrobox-podman compose -f $WINAPPS_DATA/compose.yaml down 2>/dev/null || true";
      };
    };

    # Optional desktop autostart for the launcher
  };
}
