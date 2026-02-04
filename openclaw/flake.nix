{
  description = "OpenClaw Sub-flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # The main OpenClaw module
    openclaw.url = "github:openclaw/nix-openclaw";
    openclaw.inputs.nixpkgs.follows = "nixpkgs";

    # Plugin dependencies
    nix-steipete-tools.url = "github:openclaw/nix-steipete-tools";
    # xuezh.url = "github:joshp123/xuezh";
    # padel-cli.url = "github:joshp123/padel-cli";
  };

  outputs = { self, nixpkgs, ... } @ inputs: let
    lockFile = builtins.fromJSON (builtins.readFile ./flake.lock);

    mkSource = name: let 
      node = lockFile.nodes.${name};
    in 
      if node.locked ? rev 
      then "github:${node.locked.owner}/${node.locked.repo}/${node.locked.rev}"
      else throw "Plugin '${name}' not locked in sub-flake";
  in {
    homeManagerModules.default = import ./openclaw-config.nix {
      inherit inputs mkSource;
    };
  };
}

