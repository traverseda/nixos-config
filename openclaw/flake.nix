{
  description = "OpenClaw Sub-flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    openclaw.url = "github:openclaw/nix-openclaw";
    openclaw.inputs.nixpkgs.follows = "nixpkgs";

    # nix-steipete-tools.url = "github:openclaw/nix-steipete-tools";
  };

  outputs = { self, nixpkgs, openclaw, ... } @ inputs: let
    system = "x86_64-linux";
    lockFile = builtins.fromJSON (builtins.readFile ./flake.lock);

    mkSource = name: let 
      node = lockFile.nodes.${name};
    in 
      if node.locked ? rev 
      then "github:${node.locked.owner}/${node.locked.repo}/${node.locked.rev}"
      else throw "Plugin '${name}' not locked in sub-flake";
  in {
    homeManagerModules.default = { config, lib, pkgs, ... }: {
      imports = [
        openclaw.homeManagerModules.openclaw
      ];

      programs.openclaw = {
        # Use the path directly - Nix will handle copying to store
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
          package = openclaw.packages.${system}.default;
          stateDir = "~/.openclaw";
          workspaceDir = "~/.openclaw/workspace";
          launchd.enable = true;

          plugins = [
            # { source = "${mkSource "nix-steipete-tools"}?dir=tools/oracle"; }
            # { source = "${mkSource "nix-steipete-tools"}?dir=tools/peekaboo"; }
          ];
        };
      };
    };
  };
}
