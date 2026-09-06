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

  # Computes the raw sha256 hash (stripping "hash:" or "sha256:" prefix if needed)
  iso_sha_clean = let
    raw = cfg.isoSha256;
  in
    lib.removePrefix "hash:" (lib.removePrefix "sha256:" raw);

  # Downloads and verifies Tiny10 ISO (NOT stored in Nix store)
  # ISO lives in ~/.local/share/winapps/iso/ instead
  winapps-download-iso = pkgs.writeShellScriptBin "winapps-download-iso" ''
    set -euo pipefail

    iso_url="${cfg.isoDownloadUrl}"
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
      rm "$iso_target"
      exit 1
    fi

    iso_size=$(( $(stat -c%s "$iso_target") / 1024 / 1024 ))
    echo "Verified: $iso_target ($iso_sizeMB)"
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

  # Installs Windows apps on the VM via WinApps (e.g., Adobe Acrobat Reader)
  winapps-install-apps = pkgs.writeShellScriptBin "winapps-install-apps" ''
    set -euo pipefail

    app_name="${lib.escapeShellArg (builtins.concatStringsSep " " cfg.windowsApps)}"

    if [[ -z "$app_name" ]]; then
      echo "No apps configured. Set services.winapps.windowsApps to install."
      exit 1
    fi

    if command -v winapps >/dev/null 2>&1; then
      echo "Installing apps on Windows VM: $app_name"
      winapps install --non-interactive $app_name 2>&1
      echo ""
      echo "Regenerating desktop entries..."
      mkdir -p "$HOME/.local/share/applications"
      winapps setup --non-interactive 2>/dev/null || echo "Warning: Desktop entry generation had issues."
      echo "Done."
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
      winapps.packages.${pkgs.system}.winapps
      winapps.packages.${pkgs.system}.winapps-launcher
      winapps-container-manager
      winapps-desktop-generator
      winapps-install-apps
      winapps-download-iso
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
