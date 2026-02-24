{
  description = "OpenClaw local";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-openclaw.url = "github:openclaw/nix-openclaw";
    microvm.url = "github:microvm-nix/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager, nix-openclaw, microvm, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nix-openclaw.overlays.default ];
      };
    in
    {
      nixosConfigurations."openclaw" = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          openclawSshPublicKey = "";
        };
        modules = [
          microvm.nixosModules.microvm
          home-manager.nixosModules.home-manager


          # Module 1: just the SSH key injection, needs specialArgs
          ({ openclawSshPublicKey, lib, ... }: {
            services.openssh.enable = true;
            services.openssh.settings.PasswordAuthentication = false;
            users.users.openclaw.openssh.authorizedKeys.keys =
              lib.optionals (openclawSshPublicKey != "") [ openclawSshPublicKey ];
            users.users.root.openssh.authorizedKeys.keys =
              lib.optionals (openclawSshPublicKey != "") [ openclawSshPublicKey ];
          })

          # Module 2: everything else as a plain attrset
          {
            networking.hostName = "openclaw";

            microvm = {
              hypervisor = "qemu";
              vcpu = 2;
              mem = 512;
              shares = [{
                tag = "ro-store";
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
              }];
              interfaces = [{
                type = "tap";
                id = "vm-openclaw";
                mac = "02:00:00:00:00:01";
              }];
            };

            systemd.network.enable = true;
            systemd.network.networks."20-eth" = {
              matchConfig.Name = "eth0";
              networkConfig = {
                Address = "172.16.100.2/24";
                Gateway = "172.16.100.1";
                DNS = "1.1.1.1";
              };
            };

            nixpkgs.overlays = [ nix-openclaw.overlays.default ];

            users.users.openclaw = {
              isNormalUser = true;
              home = "/home/openclaw";
            };

            home-manager.useGlobalPkgs = true;
            home-manager.users.openclaw = {
              imports = [ nix-openclaw.homeManagerModules.openclaw ];
              home.username = "openclaw";
              home.homeDirectory = "/home/openclaw";
              home.stateVersion = "24.11";
              programs.home-manager.enable = true;
              programs.openclaw = {
                documents = ./documents;
                config = {
                  gateway = {
                    mode = "local";
                    auth.token = "<gatewayToken>";
                  };
                  channels.telegram = {
                    tokenFile = "<tokenPath>";
                    allowFrom = [ ];
                    groups."*".requireMention = true;
                  };
                };
                instances.default.enable = true;
              };
            };

            system.stateVersion = "25.05";
          }
        ];
      };
    };
}
