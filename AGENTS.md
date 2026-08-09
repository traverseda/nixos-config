# AGENTS.md

## Build & deploy

```bash
# Test a host config in a VM (no bare-metal risk)
nixos-rebuild build-vm --flake ./#athame

# Build and switch a remote host from this machine
nixos-rebuild switch --flake .#hearth --target-host hearth.local --sudo --ask-sudo-password

# Build an ISO (replace <host> with e.g. athame, installer)
nix build .#nixosConfigurations.<host>.config.system.build.isoImage

# Format all Nix files
nix fmt
```

## Architecture

- **Multi-host NixOS flake** with home-manager. No CI, no tests — this is purely declarative config.
- **Hostnames are angel names** (see `hostnames.md`). Each host defined in `flake.nix` → `nixosConfigurations.<host>`.
- **Per-host hardware config** is auto-imported via `./hardware/${hostname}.nix` in `nixos/configuration.nix` (line 17). `hostname` is passed as `specialArgs`.
- **Role modules** (flat in `nixos/`): `cad.nix`, `gaming.nix`, `work.nix`, `family.nix`, `amd.nix`, `nvidia.nix`, etc. — composed per host by listing them in `flake.nix` under each host's `modules`.
- **Overlays**: `additions` (custom pkgs from `pkgs/`), `modifications` (empty, for overrides), `unstable-packages` (exposes nixpkgs-unstable as `pkgs.unstable`).
- **Home-manager**: full profile at `home-manager/traverseda/home.nix`, minimal at `home-manager/traverseda/home-minimal.nix`.

## Key conventions

- **Formatter is `alejandra`** (set in `flake.nix` outputs). Run `nix fmt` before committing.
- **`wallpapers/` uses Git LFS** (see `.gitattributes`). Make sure LFS is available when cloning.
- **`result/` symlink is gitignored** — it points to the last nix build output.
- **`allowUnfree = true`** is set globally in `configuration.nix`.
- **`mainUser`** specialArg is used for non-traverseda hosts (e.g. `selaphiel` → `mainUser = "ingrid"`).

## Home-manager on non-NixOS

```bash
home-manager switch --impure --flake "git+https://codeberg.org/traverseda/nixos-config.git?ref=main#generic-minimal" \
  --extra-experimental-features nix-command --extra-experimental-features flakes
```

## Flake inputs

| Input | Purpose |
|---|---|
| `nixpkgs` | stable (`nixos-26.05`) |
| `nixpkgs-unstable` | exposed as `pkgs.unstable` via overlay |
| `home-manager` | `release-26.05` |
| `chaotic` | catchyOS kernel (`chaotic-cx/nyx`) |
| `nixvim` | neovim config (`nixos-26.05`) |
| `plasma-manager` | KDE Plasma config |
| `nix-index-database` | `nix-locate` database |
