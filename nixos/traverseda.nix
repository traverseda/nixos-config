{
  config,
  lib,
  pkgs,
  modulesPath,
  inputs,
  ...
}: {
  services.winapps.enable = true;
  services.winapps.windowsApps = ["Acrobat"];
  services.winapps.rdpScaling = 140;
}
