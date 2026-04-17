{ pkgs, lib, inputs }:
let
  python = pkgs.python313;
  baseSet = pkgs.callPackage inputs.pyproject-nix.build.packages {
    inherit python;
  };
in
script: extraPackages:
  let
    scriptData = inputs.uv2nix.lib.scripts.loadScript {
      inherit script;
    };
    overlay = scriptData.mkOverlay { sourcePreference = "wheel"; };
    pythonSet = baseSet.overrideScope (
      lib.composeManyExtensions [
        inputs.pyproject-build-systems.overlays.wheel
        overlay
        (final: prev: 
          # Create an attribute set from the list of packages
          # We use lib.getName to get the string name for the key
          lib.listToAttrs (map (p: { 
            name = lib.getName p; 
            value = p; 
          }) extraPackages)
        )
      ]
    );
  in
    scriptData.mkVirtualEnv { inherit pythonSet; }
