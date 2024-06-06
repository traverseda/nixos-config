{ config, pkgs, lib, ... }:
{
  nixpkgs.overlays = [
    # (import (pkgs.fetchFromGitHub "https://github.com/SimulaVR/Simula.git"))
  ];

  services.monado.enable = true;

  programs.alvr = {
    enable = true;
    openFirewall = true;
  };

  environment.systemPackages = with pkgs; [
  ];
}
