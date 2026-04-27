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
      ]
    );
    uvEnv = scriptData.mkVirtualEnv { inherit pythonSet; };
  in
    pkgs.runCommand "uv-script-env" {
      buildInputs = extraPackages;
    } ''
      ln -s ${uvEnv} $out
    ''
