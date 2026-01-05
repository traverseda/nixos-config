
{ config, pkgs, lib, ... }:

{
  services.ollama = {
    enable = true;
    package = pkgs.unstable.ollama;
    acceleration = "rocm";
    rocmOverrideGfx = "11.0.0";
  };
  services.open-webui = {
    enable = true;
    port = 1331;
  };
}
