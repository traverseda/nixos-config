{
  description = "NixOS in MicroVMs";

  nixConfig = {
    extra-substituters = [ "https://microvm.cachix.org" ];
    extra-trusted-public-keys = [ "microvm.cachix.org-1:oXnBc6hRE3eX5rSYdRyMYXnfzcCxC7yKPTbZXALsqys=" ];
  };

  inputs.microvm = {
    url = "github:microvm-nix/microvm.nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, microvm }:
    let
      system = "x86_64-linux";
      lib = nixpkgs.lib;
    in {
      overlays.default = microvm.overlays.default;
      nixosModules.microvm = microvm.nixosModules.microvm;

      packages.${system} = {
        default = self.packages.${system}.openclaw;
        openclaw = self.nixosConfigurations.openclaw.config.microvm.declaredRunner;
      };

      nixosConfigurations = {
        openclaw = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit self microvm;
            packages = "";
            tapInterface = null;
          };
          modules = [
            microvm.nixosModules.microvm
            ({ lib, pkgs, config, packages, tapInterface, ... }:
            {
              microvm = {
                hypervisor = "cloud-hypervisor";
                graphics.enable = true;
                volumes = [ {
                  mountPoint = "/var";
                  image = "var.img";
                  size = 256;
                } ];
                shares = [ {
                  proto = "virtiofs";
                  tag = "ro-store";
                  source = "/nix/store";
                  mountPoint = "/nix/.ro-store";
                } ];
                interfaces = lib.optional (tapInterface != null) {
                  type = "tap";
                  id = tapInterface;
                  mac = "00:00:00:00:00:02";
                };
              };
              networking.hostName = "openclaw";
              system.stateVersion = lib.trivial.release;
              nixpkgs.overlays = [ self.overlays.default ];

              services.getty.autologinUser = "user";
              users.users.user = {
                password = "";
                group = "user";
                isNormalUser = true;
                extraGroups = [ "wheel" "video" ];
              };
              users.groups.user = {};
              security.sudo = {
                enable = true;
                wheelNeedsPassword = false;
              };

              environment.sessionVariables = {
                WAYLAND_DISPLAY = "wayland-1";
                DISPLAY = ":0";
                QT_QPA_PLATFORM = "wayland";
                GDK_BACKEND = "wayland";
                XDG_SESSION_TYPE = "wayland";
                SDL_VIDEODRIVER = "wayland";
                CLUTTER_BACKEND = "wayland";
              };

              systemd.user.services.wayland-proxy = {
                enable = true;
                description = "Wayland Proxy";
                serviceConfig = {
                  ExecStart = "${pkgs.wayland-proxy-virtwl}/bin/wayland-proxy-virtwl --virtio-gpu --x-display=0 --xwayland-binary=${pkgs.xwayland}/bin/Xwayland";
                  Restart = "on-failure";
                  RestartSec = 5;
                };
                wantedBy = [ "default.target" ];
              };

              environment.systemPackages = with pkgs; [
                xdg-utils
              ] ++ map (package:
                lib.attrByPath (lib.splitString "." package) (throw "Package ${package} not found in nixpkgs") pkgs
              ) (
                builtins.filter (package:
                  package != ""
                ) (lib.splitString " " packages));

              hardware.graphics.enable = true;
            })
          ];
        };
      };
    };
}
