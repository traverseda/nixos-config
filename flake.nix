{
  description = "Your new nix config";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";

    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    
    # You can access packages and modules from different nixpkgs revs
    # at the same time. Here's an working example:
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    # Also see the 'unstable-packages' overlay at 'overlays/default.nix'.

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:pjones/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };


    ros = {
      url = "github:lopsided98/nix-ros-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agenix.url = "github:ryantm/agenix";

    # Shameless plug: looking for a way to nixify your themes and make
    # everything match nicely? Try nix-colors!
    nix-colors.url = "github:misterio77/nix-colors";


  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nixvim,
    plasma-manager,
    ros,
    agenix,
    ...
  } @ inputs: let
    inherit (self) outputs;
    # Supported systems for your flake packages, shell, etc.
    systems = [
      "aarch64-linux"
      "i686-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    # This is a function that generates an attribute by calling a function you
    # pass to it, with each system as an argument
    forAllSystems = nixpkgs.lib.genAttrs systems;
  in {
    # Your custom packages
    # Accessible through 'nix build', 'nix shell', etc
    packages = forAllSystems (system: import ./pkgs nixpkgs.legacyPackages.${system});
    # Formatter for your nix files, available through 'nix fmt'
    # Other options beside 'alejandra' include 'nixpkgs-fmt'
    formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.alejandra);

    # Your custom packages and modifications, exported as overlays
    overlays = import ./overlays {inherit inputs;};
    # Reusable nixos modules you might want to export
    # These are usually stuff you would upstream into nixpkgs
    nixosModules = import ./modules/nixos;
    # Reusable home-manager modules you might want to export
    # These are usually stuff you would upstream into home-manager
    homeManagerModules = import ./modules/home-manager;

    # NixOS configuration entrypoint
    nixosConfigurations = {
      #Personal laptop, thinkpad t490
      athame = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;
          hostname = "athame";
        };
        modules = [
          ./nixos/configuration.nix
          ./nixos/kde-desktop.nix
          ./nixos/cad.nix
          ./nixos/zerotier.nix
          ./nixos/family.nix
        ];
      };
      #Work laptop, dell g15.
      azrael = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;
          hostname = "azrael";
        };
        modules = [
          ./nixos/configuration.nix
          ./nixos/kde-desktop.nix
          ./nixos/cad.nix
          ./nixos/zerotier.nix
          ./nixos/work.nix
        ];
      };
      #Lenovo T15
      adrial = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;
          hostname = "adrial";
        };
        modules = [
          ./nixos/configuration.nix
          ./nixos/kde-desktop.nix
          ./nixos/zerotier.nix
          ./nixos/work.nix
          ./nixos/vr-desktop.nix
          ./nixos/cad.nix
          ./nixos/gaming.nix
        ];
      };
      hearth = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;
          hostname = "hearth";
        };
        modules = [
          ./nixos/configuration.nix
          ./nixos/home-assistant.nix
          ./nixos/zerotier.nix
        ];
      };
      gwen = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;
          hostname = "gwen";
          mainUser = "gwen";
        };
        modules = [
          ./nixos/configuration.nix
          ./nixos/kde-desktop.nix
          ./nixos/family.nix
          ./nixos/zerotier.nix
        ];
      };
      bill = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs outputs;
          hostname = "bill";
          mainUser = "bill";
        };
        modules = [
          ./nixos/configuration.nix
          ./nixos/kde-desktop.nix
          ./nixos/family.nix
          ./nixos/zerotier.nix
        ];
      };
    };

    # Standalone home-manager configuration entrypoint
    # Available through 'home-manager --flake .#your-username@your-hostname'
    homeConfigurations = {
      "traverseda@generic" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
        extraSpecialArgs = {inherit inputs outputs;};
        modules = [
          # > Our main home-manager configuration file <
          ./home-manager/traverseda/home.nix
        ];
      };
    };
  };
}
