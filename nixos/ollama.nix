
{ config, pkgs, lib, ... }:

{
  services.ollama = {
    enable = true;
    # package = pkgs.unstable.ollama;
    # acceleration = "rocm";
  };
  # services.open-webui.enable = true;
}
