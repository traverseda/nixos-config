

{ pkgs, openclaw, ... }:
{
  imports = [
    openclaw.homeManagerModules.default
  ];

  services.openclaw = {
    enable = true;
    # Configure other options as needed
    # See the module documentation for available settings
  };
}

