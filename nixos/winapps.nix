{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.services.winapps;

  winapps-home = "${config.home-manager.users.traverseda.home.path}";
  iso-path = "${winapps-home}/.local/share/winapps/iso/tiny10.iso";

  compose-path = "$WINAPPS_DATA/compose.yaml";

  # Computes the raw sha256 hash (stripping "hash:" or "sha256:" prefix if needed)
  iso_sha_clean = let
    raw = cfg.tiny10iso.sha256;
  in
    lib.removePrefix "hash:" (lib.removePrefix "sha256:" raw);

  # App list as newline-separated file (read by scripts)
  apps-file = pkgs.writeText "winapps-apps" (builtins.concatStringsSep "\n" cfg.windowsApps);

  # Container manager: start/stop/restart/status/logs for the WinApps Windows VM container
  winapps-container-manager = pkgs.writeShellScriptBin "winapps-container-manager" ''
    set -euo pipefail
    export PATH="${pkgs.podman}/bin:/run/current-system/sw/bin:$PATH"

    if [[ $# -eq 0 ]]; then
      echo "Usage: winapps-container-manager {start|stop|restart|status|logs}"
      exit 1
    fi

    subcmd="$1"
    shift
    local_compose_path="$(echo $WINAPPS_DATA)/compose.yaml"

    # Ensure the compose file exists
    if [[ ! -f "$local_compose_path" ]]; then
      echo "Error: WinApps container not configured yet."
      echo "Run 'winapps-setup' first to create the configuration."
      exit 1
    fi

    # Forward to podman with isolated distrobox storage
    case "$subcmd" in
      start)
        echo "Starting WinApps Windows VM container..."
        podman-distrobox compose -f "$local_compose_path" up -d "$@"
        sleep 2
        podman-distrobox ps --filter "name=RDPWindows" --format "{{.Status}}" 2>/dev/null | grep -q "Up" || echo "Container started (status may be initializing)"

        # If apps are configured, install them
        if [[ -s "${apps-file}" ]]; then
          echo "Apps configured in winapps-apps list"
          ${winapps-apps-config}/bin/winapps-apps-config 2>&1 || echo "Warning: App installation had issues."
        fi
        ;;
      stop)
        echo "Stopping WinApps Windows VM container..."
        podman-distrobox compose -f "$local_compose_path" down
        ;;
      restart)
        echo "Restarting WinApps Windows VM container..."
        podman-distrobox compose -f "$local_compose_path" restart "$@"
        ;;
      status)
        podman-distrobox compose -f "$local_compose_path" ps "$@"
        ;;
      logs)
        podman-distrobox compose -f "$local_compose_path" logs -f "$@"
        ;;
      *)
        echo "Unknown subcommand: $subcmd"
        exit 1
        ;;
    esac
  '';

  # Downloads and verifies the Tiny10 ISO (NOT stored in Nix store)
  # ISO lives in ~/.local/share/winapps/iso/, not in the Nix store
  winapps-download-iso = pkgs.writeShellScriptBin "winapps-download-iso" ''
    set -euo pipefail

    iso_url="${cfg.tiny10iso.url}"
    iso_dir="''${HOME}/.local/share/winapps/iso"
    iso_target="''${ISO_DIR:-$iso_dir}/tiny10.iso"

    mkdir -p "$iso_dir"
    [[ -d "$ISO_DIR" ]] && iso_target="$ISO_DIR/tiny10.iso"

    if [[ -f "$iso_target" ]]; then
      actual=$(sha256sum "$iso_target" | cut -d' ' -f1)
      if [[ "$actual" == "${iso_sha_clean}" ]]; then
        echo "ISO already verified: $iso_target"
        exit 0
      fi
      echo "Hash mismatch, re-downloading..."
      rm "$iso_target"
    fi

    echo "Downloading from: $iso_url"
    ${pkgs.curl}/bin/curl -L -o "$iso_target" "$iso_url"

    actual=$(sha256sum "$iso_target" | cut -d' ' -f1)
    if [[ "$actual" != "${iso_sha_clean}" ]]; then
      echo "ERROR: Hash mismatch!"
      echo "  Expected: ${iso_sha_clean}"
      echo "  Got:      $actual"
      echo "ISO removed. Fix the hash and try again."
      rm "$iso_target"
      exit 1
    fi

    iso_size=$(( $(stat -c%s "$iso_target") / 1024 / 1024 ))
    echo "Verified: $iso_target ($iso_sizeMB)"
  '';

  # Regenerates desktop entries for Windows apps installed on the VM
  winapps-desktop-generator = pkgs.writeShellScriptBin "winapps-desktop-generator" ''
    set -euo pipefail

    # Generate desktop entries for Windows apps installed on the VM
    # This is idempotent and can be run any time
    if command -v winapps >/dev/null 2>&1; then
      mkdir -p "$HOME/.local/share/applications"
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

  # Installs and configures Windows apps on the VM
  winapps-apps-config = pkgs.writeShellScriptBin "winapps-apps-config" ''
    set -euo pipefail

    # Read apps from the file written by Nix
    apps=""
    while IFS= read -r app; do
      app=$(echo "$app" | tr -d '[:space:]')
      [[ -n "$app" ]] && apps="$apps $app"
    done < "${apps-file}"

    # If no apps configured, just regenerate desktop entries
    if [[ -z "$apps" ]]; then
      winapps-desktop-generator
      exit 0
    fi

    # Wait for Windows VM to be ready (max 180s)
    echo "Waiting for Windows VM RDP port at ${cfg.windowsHostIP}:3389..."
    for i in $(seq 1 60); do
      if ${pkgs.netcat-gnu}/bin/nc -z "${cfg.windowsHostIP}" 3389 2>/dev/null; then
        echo "Windows VM is ready."
        break
      fi
      if [[ $i -eq 60 ]]; then
        echo "Error: Windows VM not ready after 60s."
        exit 1
      fi
      sleep 2
    done

    # Install configured apps on the VM
    echo "Installing apps on Windows VM: $apps"
    winapps install --non-interactive $apps

    # Regenerate desktop entries
    echo "Generating desktop entries..."
    mkdir -p "$HOME/.local/share/applications"
    winapps-desktop-generator
    echo "App installation complete."
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

    services.winapps.windowsApps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Windows apps to install on the VM (e.g., ['Acrobat', 'Word', 'Excel']).";
    };

    services.winapps.tiny10iso.url = lib.mkOption {
      type = lib.types.str;
      default = "https://archive.org/download/tiny-w-10-pro/Tiny%20-%20W10%20Pro.iso";
      description = "URL for the Tiny10 Pro ISO.";
    };

    services.winapps.tiny10iso.sha256 = lib.mkOption {
      type = lib.types.str;
      default = "sha256-895ae2ce99950ac985857b0a74fe37ed1ab1edbe388880b6612d5abf0b1daab9";
      description = "SHA256 hash of the Tiny10 ISO. To update: nix-prefetch-url file://$(echo $HOME)/.local/share/winapps/iso/tiny10.iso";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      winapps-container-manager
      winapps-desktop-generator
      winapps-apps-config
      winapps-download-iso
      pkgs.podman
      pkgs.curl
      pkgs.netcat-gnu
    ];

    environment.sessionVariables = {
      WINAPPS_DATA = "/opt/winapps";
    };

    # Base configuration file (user overrides go to ~/.config/winapps/winapps.conf)
    environment.etc."winapps/winapps.conf".text =
      "RDP_SCALING=${toString cfg.rdpScaling}\n"
      + "WAFLAVOR=podman\n"
      + "RDP_IP=${cfg.windowsHostIP}\n"
      + "WINDOWS_USER=${cfg.windowsUser}\n"
      + "WINDOWS_PASSWORD=${cfg.windowsPassword}\n";

    # Systemd services for container lifecycle management

    # Container startup service
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

    # App installation service (runs after container is started, only if apps are configured)
    systemd.user.services.winapps-apps = {
      description = "Install and configure Windows apps on WinApps VM";
      wantedBy = ["default.target"];
      after = ["winapps-container.service"];
      requires = ["winapps-container.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        # Only runs if apps list is non-empty
        ExecStart = lib.optionalString (cfg.windowsApps != []) "${winapps-apps-config}/bin/winapps-apps-config";
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
        ExecStart = pkgs.writeShellScript "winapps-cleanup" ''
          ${pkgs.podman}/bin/podman --root %h/.local/share/distrobox-podman/storage \
            --runroot /run/user/%U/distrobox-podman \
            ps --filter name=RDPWindows --format {{.Status}} 2>/dev/null | grep -q "Up" || \
          ${pkgs.podman}/bin/podman --root %h/.local/share/distrobox-podman/storage \
            --runroot /run/user/%U/distrobox-podman \
            compose -f $WINAPPS_DATA/compose.yaml down 2>/dev/null || true;
        '';
      };
    };
  };
}
