# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
#
{pkgs, ...}: let
  xrt = pkgs.callPackage ./xrt {};
  xrt-plugin-amdxdna = pkgs.callPackage ./xrt-plugin-amdxdna {inherit xrt;};
  # XRT looks for shim plugins alongside its own libraries, so the plugin's
  # opt/xilinx/xrt/lib output has to be merged into xrt's, not just installed
  # next to it. symlinkJoin does this merge (via lndir) automatically.
  xrt-amdxdna = pkgs.symlinkJoin {
    name = "xrt-amdxdna";
    paths = [xrt xrt-plugin-amdxdna];
  };
  fastflowlm = pkgs.callPackage ./fastflowlm {inherit xrt;};
in {
  # example = pkgs.callPackage ./example { };
  # creality-print = pkgs.callPackage ./creality-print { };
  blender-cadsketcher = pkgs.callPackage ./blender-cadsketcher {};
  opencode-vision = pkgs.callPackage ./opencode-vision {};
  openrouter-image-mcp = pkgs.callPackage ./openrouter-image-mcp {};
  firefox-mcp-profile = pkgs.callPackage ./firefox-mcp-profile {};
  playwright-mcp-firefox = pkgs.callPackage ./playwright-mcp-firefox {};
  odoo-kanban = pkgs.callPackage ./odoo-kanban {};
  inherit xrt xrt-plugin-amdxdna xrt-amdxdna fastflowlm;
}
