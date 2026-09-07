{
  config,
  pkgs,
  lib,
  winapps,
  NixVirt,
  ...
}: let
  cfg = config.services.winapps;

  # NixVirt Windows VM template
  windows-vm = NixVirt.lib.domain.writeXML (NixVirt.lib.domain.templates.windows {
    name = "RDPWindows";
    uuid = "a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d";
    memory = {
      count = 8;
      unit = "GiB";
    };
    storage_vol = {
      pool = "default";
      volume = "RDPWindows.qcow2";
    };
    bridge_name = "virbr0";
    nvram_path = "/var/lib/libvirt/nvram/RDPWindows_VARS.fd";
    install_virtio = true;
    virtio_drive = true;
    virtio_video = true;
    virtio_net = true;
  });

  # Storage pool for VM
  vm-pool = NixVirt.lib.pool.writeXML {
    name = "default";
    uuid = "c4acfd00-4597-41c7-a48e-e2302234fa89";
    type = "dir";
    target = {
      path = "/var/lib/libvirt/images";
    };
  };

  # Volume for Windows VM disk
  vm-volume = NixVirt.lib.volume.writeXML {
    name = "RDPWindows.qcow2";
    capacity = {
      count = 64;
      unit = "GB";
    };
  };
in {
  imports = [
    NixVirt.nixosModules.default
  ];

  options = {
    services.winapps.enable = lib.mkEnableOption "WinApps integration via libvirt";

    services.winapps.rdpScaling = lib.mkOption {
      type = lib.types.int;
      default = 140;
      description = "Display scaling factor for Windows RDP connections.";
    };

    services.winapps.windowsApps = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Windows apps to install on the VM (e.g., ['Acrobat', 'Word', 'Excel']).";
    };

    services.winapps.enableAutostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Auto-start Windows VM on boot.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      winapps.packages.${pkgs.system}.winapps
      winapps.packages.${pkgs.system}.winapps-launcher
      pkgs.podman-compose
      pkgs.virtio-win
      pkgs.OVMFFull.fd
    ];

    # WinApps configuration for root
    environment.etc."winapps/winapps.conf".text = ''
      RDP_SCALING=${toString cfg.rdpScaling}
      WAFLAVOR=libvirt
      RDP_PORT=3389
      VM_NAME=RDPWindows
    '';

    # WinApps configuration for user
    system.activationScripts.winapps-config = ''
            echo "Setting up WinApps config for user..."
            mkdir -p /home/traverseda/.config/winapps
            cat > /home/traverseda/.config/winapps/winapps.conf << CONF
      RDP_SCALING=${toString cfg.rdpScaling}
      WAFLAVOR=libvirt
      RDP_PORT=3389
      VM_NAME=RDPWindows
      CONF
            chown traverseda: /home/traverseda/.config/winapps/winapps.conf
            chmod 600 /home/traverseda/.config/winapps/winapps.conf
    '';

    # Virtual machine declarative definition via NixVirt
    virtualisation.libvirt.enable = true;
    virtualisation.libvirt.swtpm.enable = true;

    virtualisation.libvirt.connections."qemu:///system".domains = [
      {
        definition = windows-vm;
        active = lib.mkDefault false;
        restart = true;
      }
    ];

    virtualisation.libvirt.connections."qemu:///system".pools = [
      {
        definition = vm-pool;
        active = true;
        volumes = [
          {
            definition = vm-volume;
          }
        ];
      }
    ];

    # SPICE USB redirection for USB device passthrough
    virtualisation.spiceUSBRedirection.enable = true;
  };
}
