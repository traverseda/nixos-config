{
  lib,
  buildPythonPackage,
  fetchPypi,
  deepdiff,
  zenoh,
  loguru,
  psygnal,
  rich,
  pyyaml,
  typer,
  click,
}:
# SpiriSynq (PyPI), installed from the wheel. Upstream's build backend is newer
# than nixpkgs', and the wheel is pure Python anyway.
buildPythonPackage rec {
  pname = "spirisynq";
  version = "0.4.0";
  format = "wheel";

  src = fetchPypi {
    inherit pname version format;
    dist = "py3";
    python = "py3";
    hash = "sha256-21nqT1gqvX4ujB2KMydOOS+6j6XkIn0s68yY8y0Y2Gw=";
  };

  dependencies = [deepdiff zenoh loguru psygnal rich pyyaml typer click];

  # nixpkgs pins can trail upstream's minimums (e.g. deepdiff)
  pythonRelaxDeps = true;
  dontCheckRuntimeDeps = true;

  meta = {
    description = "SpiriSynq: state synchronisation over Zenoh";
    license = lib.licenses.gpl3Plus;
  };
}
