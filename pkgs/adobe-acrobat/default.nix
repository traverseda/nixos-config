{ lib, stdenvNoCC, makeWrapper, pkgs }:

let
  pname = "adobe-acrobat-reader";
  version = "26.001.21771";
  installerName = "AcroRdrDCx642600121771_en_US.exe";
  # The nixos-26.05 pin doesn't have a cached wine build, which means
  # wineWow64Packages.stable would compile wine from source (20+ minutes).
  # pkgs.unstable (nixpkgs-unstable, wired up in overlays/unstable-packages)
  # tracks Hydra's cache far more closely, so prefer it when available and
  # fall back to the local nixpkgs pin for standalone `nix build` testing.
  wine = (pkgs.unstable or pkgs).wineWow64Packages.stable;
in
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = ./vendor/${installerName};
  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/opt $out/bin $out/share/applications
    install -m444 $src $out/opt/${installerName}

    cat > $out/bin/${pname} <<'WRAPPER'
#!/usr/bin/env bash
set -euo pipefail

PREFIX="''${XDG_DATA_HOME:-$HOME/.local/share}/wineprefixes/adobe-acrobat-reader"
INSTALLER="@out@/opt/${installerName}"

find_exe() {
  # The x64 installer's native "Acrobat\Acrobat.exe" crashes on startup
  # under Wine (unhandled page fault). The bundled 32-bit build under
  # "Acrobat\x86\Acrobat\Acrobat.exe" runs fine, so prefer it. Fall back
  # to AcroRd32.exe for older Reader-only installers, which use that name
  # instead of Acrobat.exe.
  find "$PREFIX/drive_c" -ipath '*x86*Acrobat.exe' -print -quit 2>/dev/null \
    || find "$PREFIX/drive_c" -iname 'AcroRd32.exe' -print -quit 2>/dev/null
}

if [ ! -d "$PREFIX" ] || [ -z "$(find_exe)" ]; then
  echo "Installing Adobe Acrobat Reader DC into $PREFIX (first run only) ..." >&2
  mkdir -p "$PREFIX"
  extractDir="$PREFIX/drive_c/acrobat-extract"

  # Adobe's bootstrapper self-extracts to a temp dir and hands off to
  # msiexec itself, but under Wine the MSI's cached source path ends up
  # pointing at a Program Files location the cab files were never copied
  # to, so `msiexec` fails with "cabinet not found". Extracting first and
  # running msiexec directly out of the extraction dir (where the .msi
  # and its .cab files sit side by side) avoids that.
  WINEPREFIX="$PREFIX" WINEARCH=win64 WINEDLLOVERRIDES="mscoree,mshtml=" \
    @wine@/bin/wine "$INSTALLER" -nos_o"C:\acrobat-extract" -nos_ne
  WINEPREFIX="$PREFIX" @wine@/bin/wineserver -w

  msi="$(find "$extractDir" -maxdepth 1 -iname '*.msi' -print -quit)"
  if [ -z "$msi" ]; then
    echo "Adobe Acrobat Reader DC installation failed: no .msi found under $extractDir" >&2
    exit 1
  fi
  ( cd "$extractDir" && WINEPREFIX="$PREFIX" \
      @wine@/bin/wine msiexec /i "$(basename "$msi")" /qb EULA_ACCEPT=YES )
  WINEPREFIX="$PREFIX" @wine@/bin/wineserver -w
  rm -rf "$extractDir"
fi

exe="$(find_exe)"
if [ -z "$exe" ]; then
  echo "Adobe Acrobat Reader DC installation failed: no Acrobat executable found under $PREFIX" >&2
  exit 1
fi

exec env WINEPREFIX="$PREFIX" @wine@/bin/wine "$exe" "$@"
WRAPPER
    substituteInPlace $out/bin/${pname} \
      --replace-fail '@wine@' '${wine}' \
      --replace-fail '@out@' "$out"
    chmod +x $out/bin/${pname}

    cat > $out/share/applications/${pname}.desktop <<EOF
[Desktop Entry]
Name=Adobe Acrobat Reader DC
Comment=View, sign, and annotate PDFs (runs under Wine)
Exec=$out/bin/${pname} %f
Terminal=false
Type=Application
Categories=Office;Viewer;
MimeType=application/pdf;
EOF

    runHook postInstall
  '';

  meta = {
    description = "Adobe Acrobat Reader DC, run under Wine (vendored offline installer)";
    homepage = "https://www.adobe.com/acrobat/pdf-reader.html";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = pname;
  };
}
