{
  lib,
  pkgs,
  ...
}: {
  # The tailscale0 interface is the tailnet; trust it like the ZeroTier interface.
  networking.firewall.trustedInterfaces = ["tailscale0"];

  services.tailscale = {
    enable = true;
    # stable nixpkgs (26.05) ships <1.98.9 (TS-2026-005..009 unfixed); use unstable 1.102.2
    package = pkgs.unstable.tailscale;
  };
}
