{ config, pkgs, lib, ... }:

{

  environment.systemPackages = with pkgs; [
    pkgs.openscad
    pkgs.blender
    pkgs.freecad
    (pkgs.appimageTools.wrapType2
      {
        name = "creality-print";
        src = pkgs.fetchurl {
          url = "https://file2-cdn.creality.com/file/05a4538e0c7222ce547eb8d58ef0251e/Creality_Print-v4.3.7.6627-x86_64-Release.AppImage";
          sha256 = "sha256-WUsL7UbxSY94H4F1Ww8vLsfRyeg2/DZ+V4B6eH3M6+M=";
        };
    })
    # (pkgs.appimageTools.wrapType2
    #   {
    #     name = "orca-slicer";
    #     src = pkgs.fetchurl {
    #       url = "https://github.com/SoftFever/OrcaSlicer/releases/download/v2.0.0/OrcaSlicer_Linux_V2.0.0.AppImage";
    #       sha256 = "sha256-PcCsqF1RKdSrbdp1jCF0n5Mu30EniaBEuJNw3XdPhO4=";
    #     };
    # })
  ];

}
