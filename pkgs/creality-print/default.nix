{ pkgs ? import <nixpkgs> {} }:

let
  creality-print = pkgs.appimageTools.wrapType2 {
    name = "creality-print";
    src = pkgs.fetchurl {
      url = "https://file2-cdn.creality.com/file/05a4538e0c7222ce547eb8d58ef0251e/Creality_Print-v4.3.7.6627-x86_64-Release.AppImage";
      sha256 = "sha256-WUsL7UbxSY94H4F1Ww8vLsfRyeg2/DZ+V4B6eH3M6+M=";
    };
    profile = ''
      export LC_ALL=C.UTF-8
    '';
    multiPkgs = pkgs: with pkgs; [ qt5.qtbase libGL libz ];
  };

  desktopItem = pkgs.makeDesktopItem {
    name = "creality-print";
    exec = "${creality-print}/bin/creality-print";
    icon = "creality-print";
    desktopName = "Creality Print";
    genericName = "3D Printer Software";
    categories = [ "Graphics" ];
  };

in
pkgs.stdenv.mkDerivation {
  name = "creality-print-app";
  buildInputs = [ creality-print ];

  nativeBuildInputs = [ pkgs.makeWrapper ];

  unpackPhase = "true";

  installPhase = ''
    mkdir -p $out/bin $out/share/applications
    cp ${creality-print}/bin/* $out/bin
    ln -s ${desktopItem}/share/applications/* $out/share/applications/
  '';

  meta = with pkgs.lib; {
    description = "Creality Print is a 3D printer software for Creality printers";
    homepage = "https://www.creality.com/";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
