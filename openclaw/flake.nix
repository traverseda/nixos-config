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

      programs.openclaw = {
        documents = ./documents;

        config = {
          gateway = {
            mode = "local";
            auth = {
              token = "<gatewayToken>";
            };
          };
        };

        instances.default = {
          enable = true;
          package = openclaw.packages.x86_64-linux.default;
          stateDir = "~/.openclaw";
          workspaceDir = "~/.openclaw/workspace";

          plugins = [
            # { source = "github:openclaw/nix-steipete-tools?dir=tools/oracle"; }
            # { source = "github:openclaw/nix-steipete-tools?dir=tools/peekaboo"; }
          ];
        };
      };
    };
  };
}

