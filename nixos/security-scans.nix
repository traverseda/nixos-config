# Periodically ARP-scans the local subnet and raises a KDE notification for
# common ARP-spoofing / MITM indicators: the default gateway's MAC address
# changing, or two different MACs answering for the same IP in one scan.
{ config, pkgs, lib, specialArgs, ... }:

let
  notifyUser = specialArgs.mainUser or "traverseda";
  scanInterval = "3min";

  arpSecurityScan = pkgs.writeShellApplication {
    name = "arp-security-scan";
    runtimeInputs = with pkgs; [ arp-scan iproute2 gnugrep gawk util-linux coreutils libnotify networkmanager ];
    text = ''
      notify_user=${lib.escapeShellArg notifyUser}

      notify() {
        title=$1
        body=$2
        uid=$(id -u "$notify_user") || return 0
        runtime_dir="/run/user/$uid"
        if [ ! -S "$runtime_dir/bus" ]; then
          echo "no session bus for $notify_user, dropping notification: $title: $body" >&2
          return 0
        fi
        runuser -u "$notify_user" -- env \
          DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime_dir/bus" \
          XDG_RUNTIME_DIR="$runtime_dir" \
          notify-send --urgency=critical --app-name="Security scan" --icon=security-medium "$title" "$body"
      }

      default_route=$(ip route show default | head -n1)
      iface=$(printf '%s\n' "$default_route" | grep -oP '(?<=dev )\S+' || true)
      gateway_ip=$(printf '%s\n' "$default_route" | grep -oP '(?<=via )\S+' || true)

      if [ -z "$iface" ] || [ -z "$gateway_ip" ]; then
        echo "no default route found, skipping scan" >&2
        exit 0
      fi

      scan_output=$(arp-scan --interface="$iface" --localnet --quiet --plain 2>/dev/null || true)
      pairs=$(printf '%s\n' "$scan_output" | awk 'NF==2 {print $1"\t"tolower($2)}' | sort -u)

      # Two different MACs answering for the same IP in this scan is a classic
      # ARP-spoofing / duplicate-IP signature.
      conflicts=$(printf '%s\n' "$pairs" | awk -F'\t' '
        { n[$1]++; m[$1] = (n[$1] == 1) ? $2 : m[$1] ", " $2 }
        END { for (ip in n) if (n[ip] > 1) print ip "\t" m[ip] }
      ')
      if [ -n "$conflicts" ]; then
        while IFS=$'\t' read -r ip macs; do
          [ -z "$ip" ] && continue
          notify "ARP conflict detected" "$ip was claimed by multiple MAC addresses: $macs"
        done <<< "$conflicts"
      fi

      # Track the gateway's MAC address per-network (roaming between wifi
      # networks/SSIDs legitimately changes both the gateway IP and MAC, so a
      # single global "last known gateway mac" would false-positive on every
      # network switch). Key on the active NetworkManager connection name,
      # which for wifi is normally the SSID, falling back to the interface
      # name if NetworkManager has no opinion.
      network_key=$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null || true)
      if [ -z "$network_key" ] || [ "$network_key" = "--" ]; then
        network_key="iface:$iface"
      fi

      gateway_mac_file="$STATE_DIRECTORY/gateway-macs"
      touch "$gateway_mac_file"
      gw_mac=$(printf '%s\n' "$pairs" | awk -F'\t' -v ip="$gateway_ip" '$1 == ip { print $2; exit }')
      if [ -n "$gw_mac" ]; then
        declare -A known_gateway_mac=()
        while IFS=$'\t' read -r key mac; do
          [ -n "$key" ] && known_gateway_mac["$key"]="$mac"
        done < "$gateway_mac_file"

        old_mac="${known_gateway_mac[$network_key]:-}"
        if [ -n "$old_mac" ] && [ "$old_mac" != "$gw_mac" ]; then
          notify "Gateway MAC address changed" "On network '$network_key', gateway $gateway_ip was $old_mac, now $gw_mac. This can indicate ARP spoofing or a MITM attack."
        fi
        known_gateway_mac["$network_key"]="$gw_mac"

        {
          for key in "''${!known_gateway_mac[@]}"; do
            printf '%s\t%s\n' "$key" "''${known_gateway_mac[$key]}"
          done
        } > "$gateway_mac_file.tmp"
        mv "$gateway_mac_file.tmp" "$gateway_mac_file"
      fi
    '';
  };
in
{
  systemd.services.arp-security-scan = {
    description = "Scan the local network for ARP spoofing indicators";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${arpSecurityScan}/bin/arp-security-scan";
      StateDirectory = "security-scans";
    };
  };

  systemd.timers.arp-security-scan = {
    description = "Periodic ARP spoofing scan timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = scanInterval;
      Persistent = false;
    };
  };
}
