{ config, pkgs, lib, ... }:

{

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
    gamescopeSession.enable = true;

  };
  programs.steam.extraCompatPackages = [ pkgs.proton-ge-bin];
  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    discord
    heroic
    mangohud
    (writeShellScriptBin "steam-big-picture" ''
      #!/usr/bin/env bash
      set -xeuo pipefail

      gamescopeArgs=(
          --adaptive-sync # VRR support
          --hdr-enabled
          --rt
          --steam
      )
      steamArgs=(
          -pipewire-dmabuf
          -tenfoot
      )
      mangoConfig=(
          cpu_temp
          gpu_temp
          ram
          vram
      )
      mangoVars=(
          MANGOHUD=1
          MANGOHUD_CONFIG="''$(IFS=,; echo "''${mangoConfig[*]}")"
      )

      export "''${mangoVars[@]}"
      exec gamescope "''${gamescopeArgs[@]}" -- steam "''${steamArgs[@]}"
    '')
  ];
}

