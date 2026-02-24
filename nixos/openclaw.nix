{ config, pkgs, lib, inputs, ... }:

let
  # Generate a deterministic ED25519 keypair at build time
  sshKeyPair = pkgs.runCommand "openclaw-vm-keypair" {} ''
    mkdir -p $out
    ${pkgs.openssh}/bin/ssh-keygen \
      -t ed25519 \
      -C "openclaw-vm" \
      -N "" \
      -f $out/id_ed25519
  '';
in
{
  imports = [ inputs.microvm.nixosModules.host ];

  # ── MicroVM ────────────────────────────────────────────────────────────────
  microvm.vms."openclaw" = {
    flake = inputs.openclaw-vm;
    autostart = true;
    # Pass the public key into the sub-flake as a specialArg
    specialArgs = {
      openclawSshPublicKey = builtins.readFile "${sshKeyPair}/id_ed25519.pub";
    };
  };

  # ── Expose keypair as a package for easy CLI access ───────────────────────
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "ssh-openclaw" ''
      exec ssh \
        -i ${sshKeyPair}/id_ed25519 \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        openclaw@openclaw.localhost "$@"
    '')
  ];

  # ── Host-internal bridge with NAT uplink ──────────────────────────────────
  systemd.network.enable = true;

  systemd.network.netdevs."10-microvm" = {
    netdevConfig = {
      Name = "microvm-br";
      Kind = "bridge";
    };
  };

  systemd.network.networks."10-microvm" = {
    matchConfig.Name = "microvm-br";
    networkConfig = {
      Address = "172.16.100.1/24";
      IPMasquerade = "ipv4";
      IPv4Forwarding = true;
    };
    linkConfig.RequiredForOnline = "no";
  };

  systemd.network.networks."11-microvm-tap" = {
    matchConfig.Name = "vm-openclaw";
    networkConfig.Bridge = "microvm-br";
  };

  networking.hosts = {
    "172.16.100.2" = [ "openclaw.localhost" ];
  };

  # ── OpenSnitch ─────────────────────────────────────────────────────────────
  services.opensnitch = {
    enable = true;

    rules = {
      "100-ask-vm" = {
        name = "100-ask-vm";
        enabled = true;
        precedence = true;
        created = "2026-02-19T09:00:00Z";
        action = "prompt";
        duration = "always";
        operator = {
          type = "list";
          operand = "list";
          sensitive = false;
          list = [
            {
              type = "simple";
              sensitive = false;
              operand = "iface.in";
              data = "microvm-br";
            }
            {
              type = "simple";
              sensitive = false;
              operand = "iface.out";
              data = "microvm-br";
            }
          ];
        };
      };

      "000-allow-all" = {
        name = "000-allow-all";
        enabled = true;
        precedence = true;
        created = "2026-02-19T09:00:00Z";
        action = "allow";
        duration = "always";
        operator = {
          type = "network";
          operand = "dest.network";
          sensitive = false;
          data = "0.0.0.0/0";
          list = [];
        };
      };

      "001-allow-all-ipv6" = {
        name = "001-allow-all-ipv6";
        enabled = true;
        precedence = true;
        created = "2026-02-19T09:00:00Z";
        action = "allow";
        duration = "always";
        operator = {
          type = "network";
          operand = "dest.network";
          sensitive = false;
          data = "::/0";
          list = [];
        };
      };
    };
  };

  # ── OpenSnitch UI via Home Manager ────────────────────────────────────────
  home-manager.users.traverseda = {
    services.opensnitch-ui.enable = true;
  };
}

