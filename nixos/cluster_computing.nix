{ config, pkgs, lib, ... }:

{
  # 1. Enable Firewall (interface specific) and Firejail
  networking.firewall.interfaces."zt_aura".allowedTCPPorts = [ 2222 ];
  programs.firejail.enable = true;

  # Enable fping and set it setuid for network discovery without root
  security.wrappers.fping = {
    source = "${pkgs.fping}/bin/fping";
    owner = "root";
    group = "root";
    setuid = true;
  };

  # 2. Define the "cluster" user with your specific public key
  users.users.cluster = {
    isNormalUser = true;
    shell = "${pkgs.bash}/bin/bash";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGJvfF/wgww2J0LHfp0ETOavKMuvcDEBBPljiacrTxy8"
    ];
  };

  # 3. Create a custom configuration for the separate SSH instance
  # CRITICAL: We add 'AcceptEnv CLUSTER_ENV' here.
  environment.etc."sshd_cluster_config".text = ''
    ListenAddress 0.0.0.0
    Port 2222

    PermitRootLogin no
    PasswordAuthentication no
    AllowUsers cluster

    # Accept the CLUSTER_ENV variable from the client
    AcceptEnv CLUSTER_ENV

    # Use the wrapper script
    ForceCommand /etc/ssh_cluster_login_wrapper.sh
    HostKey /etc/ssh/ssh_host_ed25519_key
    HostKey /etc/ssh/ssh_host_rsa_key
    PidFile /run/sshd-cluster.pid
  '';

  # GENERIC EXECUTION FRAMEWORK WRAPPER:
  # This script intercepts requests. If CLUSTER_ENV is set, it wraps the 
  # execution in 'nix-shell -p <packages>'. If not, it runs raw in firejail.
  environment.etc."ssh_cluster_login_wrapper.sh".text = ''
    #!/run/current-system/sw/bin/sh

    # Check if the client sent a desired environment
    if [ -n "$CLUSTER_ENV" ]; then
        # CLUSTER_ENV is set (e.g., "gcc ffmpeg vllm")
        # We build the command: nix-shell -p <packages> --
        PACKAGER_CMD="${pkgs.nix}/bin/nix-shell -p $CLUSTER_ENV --"
    else
        # No specific environment requested, run raw
        PACKAGER_CMD=""
    fi

    if [ -n "$SSH_ORIGINAL_COMMAND" ]; then
        # AUTOMATED COMMAND (e.g., distcc job, make, ffmpeg)
        # Run: firejail [nix-shell -p pkgs --] "actual command"
        exec ${pkgs.firejail}/bin/firejail $PACKAGER_CMD "$SSH_ORIGINAL_COMMAND"
    else
        # INTERACTIVE LOGIN
        # Run: firejail [nix-shell -p pkgs --] bash -i
        # If PACKAGER_CMD is empty, this acts as just firejail bash
        exec ${pkgs.firejail}/bin/firejail $PACKAGER_CMD "${pkgs.bash}/bin/bash -i"
    fi
  '';
  environment.etc."ssh_cluster_login_wrapper.sh".mode = "0755";

  # 4. Systemd service for the separate SSH daemon
  # Bound to the cluster-worker-active gate as requested.
  systemd.services.sshd-cluster = {
    description = "SSH Daemon for Cluster Worker User";
    after = [ "network.target" "cluster-worker-active.service" ];
    bindsTo = [ "cluster-worker-active.service" ];
    wantedBy = [ "cluster-worker-active.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.openssh}/bin/sshd -f /etc/sshd_cluster_config";
      Restart = "always";
      Type = "simple";
    };
  };

  # 5. Create the 'cluster-nodes' utility script
  environment.systemPackages = with pkgs; [
    fping
    (pkgs.writeShellScriptBin "cluster-nodes" ''
      #!/usr/bin/env bash
      SUBNET="''${1:-172.25.26.0/24}"
      NODES=$(fping -g "$SUBNET" -a -q 2>/dev/null)
      if [[ -z "$NODES" ]]; then echo ""; else echo "''${NODES}" | tr '\n' ' ' | sed 's/ $//'; fi
    '')
  ];

  # Ensure standard SSH is enabled
  services.openssh.enable = true;

  # --- EXISTING READINESS LOGIC BELOW ---
  # ... (Unchanged logic for cluster-worker-active, udev, dispatcher, etc.) ...

  systemd.services.cluster-worker-active = {
    description = "Cluster Worker Availability Gate";
    after = [ "cluster-worker-ac-power.service" "cluster-worker-unmetered-internet.service" "network-online.target" ];
    bindsTo = [ "cluster-worker-ac-power.service" "cluster-worker-unmetered-internet.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.systemd}/bin/systemd-inhibit --what=sleep:idle --who=cluster-worker-active --why='Distributed compute job in progress' --mode=block -- ${pkgs.coreutils}/bin/sleep infinity";
    };
  };

  systemd.services.cluster-worker-ac-power = {
    description = "Cluster Worker AC Power Latch";
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop  = "${pkgs.coreutils}/bin/true";
    };
  };

  systemd.services.cluster-worker-unmetered-internet = {
    description = "Cluster Worker Unmetered Internet Latch";
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/true";
      ExecStop  = "${pkgs.coreutils}/bin/true";
    };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="0", \
      RUN+="${pkgs.systemd}/bin/systemctl stop cluster-worker-ac-power.service"
    SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_ONLINE}=="1", \
      RUN+="${pkgs.systemd}/bin/systemctl start cluster-worker-ac-power.service"
  '';

  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "cluster-worker-nm-dispatcher" ''
        ACTION="$2"
        case "$ACTION" in
          up|connectivity-change|dhcp4-change|dhcp6-change|down|pre-down) ;;
          *) exit 0 ;;
        esac

        METERED=$(${pkgs.dbus}/bin/dbus-send \
          --system \
          --print-reply \
          --dest=org.freedesktop.NetworkManager \
          /org/freedesktop/NetworkManager \
          org.freedesktop.DBus.Properties.Get \
          string:org.freedesktop.NetworkManager \
          string:Metered \
          2>/dev/null \
          | ${pkgs.gawk}/bin/awk '/uint32/ {print $2}')

        case "$METERED" in
          1|3) systemctl stop  cluster-worker-unmetered-internet.service ;;
          *)   systemctl start cluster-worker-unmetered-internet.service ;;
        esac
      '';
    }
  ];
}
