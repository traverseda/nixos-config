{ inputs, outputs, config, pkgs, lib, ... }:
let
  # Fetch Simula source code from GitHub
  # simulaSrc = pkgs.fetchFromGitHub {
  #   owner = "traverseda";
  #   repo = "Simula";
  #   rev = "b232d1c672fbbda502ca4723e8f3fc5379dc7eec";
  #   sha256 = "DmsUxSJZCqMjkvKx51NYomJ4Bm/fJ5h6rYSxkdpu1MM=";
  #   fetchSubmodules = true;
  # };

  # # Build the Simula package
  # simula = pkgs.callPackage "${simulaSrc}/Simula.nix" {
  #   onNixOS = true;
  #   devBuild = false;
  #   profileBuild = false;
  #   externalSrc = simulaSrc;
  # };
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager

  ];
  nixpkgs.overlays = [
    # (import (pkgs.fetchFromGitHub "https://github.com/SimulaVR/Simula.git"))
  ];
  environment.systemPackages = [
    pkgs.wlx-overlay-s
    pkgs.stardust-xr-server
    pkgs.stardust-xr-protostar
    pkgs.stardust-xr-flatland
    pkgs.stardust-xr-atmosphere

    (pkgs.writeShellScriptBin "stardust_startup" ''
      ${pkgs.xwayland-satellite}/bin/xwayland-satellite :10 &
      export DISPLAY=:10 &
      sleep 0.1;

      ${pkgs.stardust-xr-flatland}/bin/flatland &
      ${pkgs.stardust-xr-gravity}/bin/gravity -- 0 0.0 -0.5 hexagon_launcher &
    '')
    (pkgs.writeShellScriptBin "stardust" ''
      ${pkgs.stardust-xr-server}/bin/stardust-xr-server -o 1 -e stardust_startup "$@"
    '')
  ];


  home-manager = {
    extraSpecialArgs = { inherit inputs outputs; };
    backupFileExtension = ".bak";
    users = {
      traverseda = import ../home-manager/traverseda/vr.nix;
    };
  };

  services.wivrn = {
    enable = true;
    openFirewall = true;

    # Write information to /etc/xdg/openxr/1/active_runtime.json, VR applications
    # will automatically read this and work with WiVRn (Note: This does not currently
    # apply for games run in Valve's Proton)
    defaultRuntime = true;

    # Run WiVRn as a systemd service on startup
    autoStart = false;

    # Config for WiVRn (https://github.com/WiVRn/WiVRn/blob/master/docs/configuration.md)
    config = {
      enable = true;
      json = {
        # 1.0x foveation scaling
        scale = 1.0;
        # 100 Mb/s
        bitrate = 100000000;
        encoders = [
          {
            encoder = "vaapi";
            codec = "h265";
            # 1.0 x 1.0 scaling
            width = 1.0;
            height = 1.0;
            offset_x = 0.0;
            offset_y = 0.0;
          }
        ];
      };
    };
  };

  # programs.envision = {
  #   enable = true;
  #   openFirewall = true; # This is set true by default
  # };
}
