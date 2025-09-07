
{
#  config,
   pkgs,
#  lib,
#  ros,
... }:
{
  virtualisation.waydroid.enable = true;
  environment.systemPackages =  [ pkgs.waydroid-helper ];


}
