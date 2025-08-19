{ pkgs ? import <nixpkgs> {} }:

let
  # URL and SHA256 for Creality Print AppImage
  appimageUrl = "https://file2-cdn.creality.com/file/05a4538e0c7222ce547eb8d58ef0251e/Creality_Print-v4.3.7.6627-x86_64-Release.AppImage";
  appimageSha256 = "sha256-WUsL7UbxSY94H4F1Ww8vLsfRyeg2/DZ+V4B6eH3M6+M=";

  # Extract version from the filename
  version = "4.3.7.6627";

  # Wrap the AppImage using appimageTools
  creality-print = pkgs.appimageTools.wrapType2 {
    name = "creality-print";
    version = version;
    src = pkgs.fetchurl {
      url = appimageUrl;
      sha256 = appimageSha256;
    };
    extraPkgs = pkgs: with pkgs; [ qt5.qtbase libGL libz ];
  };

in
# Define the package
pkgs.stdenv.mkDerivation {
  name = "creality-print-${version}";
  buildInputs = [ creality-print pkgs.bash ];

  nativeBuildInputs = [ pkgs.makeWrapper pkgs.icoutils pkgs.appimageTools ];

  # No sources to unpack
  unpackPhase = "true";

  # Installation phase
  installPhase = ''
    mkdir -p $out/bin $out/share/applications $out/share/icons/hicolor/256x256/apps

    # Copy the wrapped binary
    cp ${creality-print}/bin/* $out/bin

    # Try to extract the icon from the original AppImage
    # First, extract the AppImage
    ${pkgs.appimageTools.appimage-run}/bin/appimage-run ${pkgs.fetchurl {
      url = appimageUrl;
      sha256 = appimageSha256;
    }} --appimage-extract 2>/dev/null || true
    
    # Find and copy the icon
    if [ -d squashfs-root ]; then
      find squashfs-root -name "*.png" -o -name "*.svg" | head -1 | while read icon; do
        cp "$icon" $out/share/icons/hicolor/256x256/apps/creality-print.''${icon##*.} || true
      done
      # Clean up
      rm -rf squashfs-root
    fi

    # Create the desktop entry
    cat > $out/share/applications/creality-print.desktop <<EOF
[Desktop Entry]
Name=Creality Print
Exec=$out/bin/creality-print
Icon=creality-print
Type=Application
Categories=Graphics;
EOF
  '';

  # Package metadata
  meta = with pkgs.lib; {
    description = "Creality Print is a 3D printer software for Creality printers";
    homepage = "https://www.creality.com/";
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
