{
  description = "OpenClaw Sub-flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    openclaw = {
      url = "github:openclaw/nix-openclaw";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, openclaw, ... }: {
    homeManagerModules.default = { config, lib, pkgs, ... }: {
      imports = [
        openclaw.homeManagerModules.openclaw
      ];

      nixpkgs.overlays = [
        openclaw.overlays.default
      ];

      programs.openclaw = {
        documents = ./documents;

        instances.default = {
          enable = true;
          plugins = [
            # { source = "github:openclaw/nix-steipete-tools?dir=tools/oracle"; }
            # { source = "github:openclaw/nix-steipete-tools?dir=tools/peekaboo"; }
          ];
        };
      };

      # Override the broken config file with a working one
      home.file.".openclaw/openclaw.json".force = true;
      home.file.".openclaw/openclaw.json".text = ''
        {
          "gateway": {
            "mode": "local",
            "auth": {
              "token": "<gatewayToken>"
            }
          }
        }
      '';
    };
  };
}

