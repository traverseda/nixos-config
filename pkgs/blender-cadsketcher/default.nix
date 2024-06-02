{ lib, blender, python3Packages, fetchFromGitHub, pkgs }:

let
  py-slvs = python3Packages.buildPythonPackage rec {
    pname = "py-slvs";
    version = "1.0.6";

    src = fetchFromGitHub {
      owner = "realthunder";
      repo = "slvs_py";
      rev = "v${version}";
      sha256 = "hBuW8Guqli/jMFPygG8jq5ZLs508Ss+lmBORuW6yTxs=";
    };

    nativeBuildInputs = [ pkgs.swig pkgs.cmake pkgs.ninja ];

    cmakeFlags = [
      "-B."
      "-H${src}"
    ];

    propagatedBuildInputs = with python3Packages; [ setuptools wheel scikit-build cmake ninja ];

    meta = {
      description = "Python binding of SOLVESPACE geometry constraint solver";
      homepage = "https://github.com/realthunder/slvs_py";
      license = lib.licenses.gpl3;
    };
  };
in
  blender.overrideAttrs (oldAttrs: {
    name = "blender-cadsketcher-${oldAttrs.version}";
    buildInputs = oldAttrs.buildInputs ++ [ py-slvs ];
  })
