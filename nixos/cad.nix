{ config, pkgs, lib, ... }:

{

  environment.systemPackages = with pkgs; [
    pkgs.openscad
    pkgs.blender
    pkgs.freecad
  ];

}
