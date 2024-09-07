{ pkgs ? import <nixpkgs> {} }:

let
  # URL and SHA256 for Creality Print AppImage
  appimageUrl = "https://file2-cdn.creality.com/file/05a4538e0c7222ce547eb8d58ef0251e/Creality_Print-v4.3.7.6627-x86_64-Release.AppImage";
  appimageSha256 = "sha256-WUsL7UbxSY94H4F1Ww8vLsfRyeg2/DZ+V4B6eH3M6+M=";

  # Wrap the AppImage using appimageTools
  creality-print = pkgs.appimageTools.wrapType2 {
    name = "creality-print";
    src = pkgs.fetchurl {
      url = appimageUrl;
      sha256 = appimageSha256;
    };
    profile = ''
      export LC_ALL=C.UTF-8
    '';
    multiPkgs = pkgs: with pkgs; [ qt5.qtbase libGL libz ];
  };

in
# Define the package
pkgs.stdenv.mkDerivation {
  name = "creality-print";
  buildInputs = [ creality-print pkgs.bash ];

  nativeBuildInputs = [ pkgs.makeWrapper pkgs.icoutils pkgs.unpacker ];

  # No sources to unpack
  unpackPhase = "true";

  # Extraction phase to get the icon from the AppImage
  installPhase = ''
    mkdir -p $out/bin $out/share/applications $out/share/icons/hicolor/256x256/apps

    # Extract the AppImage content
    appimage-extract ${creality-print}/bin/creality-print

    # Find and copy the icon (typically the largest icon available)
    cp ./squashfs-root/*.png $out/share/icons/hicolor/256x256/apps/creality-print.png || true

    # Copy the binary files
    cp ${creality-print}/bin/* $out/bin

    # Create the desktop entry with the extracted icon
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
