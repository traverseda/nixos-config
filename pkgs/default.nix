# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
#
{pkgs, ...}: {
  # example = pkgs.callPackage ./example { };
  # creality-print = pkgs.callPackage ./creality-print { };
  blender-cadsketcher = pkgs.callPackage ./blender-cadsketcher {};
  opencode-vision = pkgs.callPackage ./opencode-vision {};
  openrouter-image-mcp = pkgs.callPackage ./openrouter-image-mcp {};
}
