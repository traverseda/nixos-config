{ lib, blender, python3Packages, fetchFromGitHub, pkgs, fetchurl}:

let
  py-slvs = python3Packages.buildPythonPackage rec {

    pname = "py-slvs";
    version = "1.0.6";
    src = fetchurl {
      url = "https://pypi.org/packages/source/p/py_slvs/py_slvs-1.0.6.tar.gz";
      sha256 = "sha256-U6T/aXy0JTC1ptL5oBmch0ytSPmIkRA8XOi31NpArnI=";
    };

    pyproject = true;

    nativeBuildInputs = with pkgs; [
      swig
    ];

    propagatedBuildInputs = with python3Packages; [
      cmake
      ninja
      setuptools
      scikit-build
    ];

    dontUseCmakeConfigure = true;

    meta = with pkgs.lib; {
      description = "Python binding of SOLVESPACE geometry constraint solver";
      homepage = "https://github.com/realthunder/slvs_py";
      license = licenses.gpl3;
    };

  };
in
  blender.overrideAttrs (oldAttrs: {
    name = "blender-cadsketcher-${oldAttrs.version}";
    buildInputs = oldAttrs.buildInputs ++ [ py-slvs ];
  })
