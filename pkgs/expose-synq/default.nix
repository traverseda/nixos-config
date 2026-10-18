{
  lib,
  buildPythonApplication,
  fetchPypi,
  typer,
  rich,
  loguru,
  pathspec,
  json5,
  mfusepy,
  cryptography,
  makeWrapper,
  fuse3,
  bubblewrap,
  iproute2,
  spirisynq,
}:
# Expose a local workspace (files, sandboxed exec) to remote agents over
# SpiriSynq. Installed from the PyPI wheel (upstream needs uv_build 0.11).
# Runtime helpers: libfuse3 for `mount`, bwrap for the exec sandbox, ip for
# interface discovery. fusermount3 must come from the setuid wrapper in
# /run/wrappers/bin (programs.fuse), so it is deliberately not pinned here.
buildPythonApplication rec {
  pname = "expose-synq";
  version = "0.2.1";
  format = "wheel";

  src = fetchPypi {
    pname = "expose_synq";
    inherit version format;
    dist = "py3";
    python = "py3";
    hash = "sha256-wjmELNf+OvW2tNFkpymGafW5pNlwlcH7h+48HmXiVKw=";
  };

  nativeBuildInputs = [makeWrapper];

  dependencies = [spirisynq typer rich loguru pathspec json5 mfusepy cryptography];

  # nixpkgs' json5/cryptography trail upstream's minimums
  pythonRelaxDeps = true;
  dontCheckRuntimeDeps = true;

  makeWrapperArgs = [
    "--set-default FUSE_LIBRARY_PATH ${lib.getLib fuse3}/lib/libfuse3.so"
    "--prefix PATH : ${lib.makeBinPath [bubblewrap iproute2]}"
  ];

  pythonImportsCheck = ["synq_expose"];

  meta = {
    description = "Expose a local workspace (files, sandboxed exec) to remote agents over SpiriSynq";
    homepage = "https://github.com/traverseda/expose-synq";
    license = lib.licenses.gpl3Plus;
    mainProgram = "expose-synq";
  };
}
