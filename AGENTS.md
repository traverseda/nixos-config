# AGENTS.md

## WinApps module

**Created** 2026-09-06. Uses distrobox's isolated podman storage + declarative systemd lifecycle.

- Creates a `podman` wrapper that routes all podman calls to `podman-distrobox` (storage at `~/.local/share/distrobox-podman/storage`), so WinApps containers share the same isolated podman as distrobox.
- Provides `services.winapps` options: `enable`, `rdpScaling` (default 140), `windowsHostIP` (default 192.168.122.1), `windowsUser`, `windowsPassword`, `startOnLogin` (default true), `windowsApps` (list of apps to install).
- Sets `WINAPPS_CONTAINER_MANAGER` env var for winapps to find the wrapper.
- Installed on azrael via `./nixos/winapps.nix` module.

### Container lifecycle

- **`winapps-container-manager {start|stop|restart|status|logs}`** — declarative container management via systemd user service.
- `systemctl --user start winapps-container` — starts the Windows VM container (uses `podman-distrobox compose` with isolated storage).
- Timer runs daily cleanup of stale container resources.
- Config at `/opt/winapps/compose.yaml` (created by `winapps-setup`).

### App installation

- **`winapps-desktop-generator`** — idempotent script that regenerates desktop entries for Windows apps installed on the VM.
- Run after installing new Windows apps on the Windows VM.
- Uses `winapps setup` internally to detect installed apps.
- **`winapps-install-apps`** — installs Windows apps on the VM via WinApps' `winapps install --non-interactive` + regenerates desktop entries.
- Apps listed in `services.winapps.windowsApps = ["Acrobat"];` are installed automatically when this script is run.
- Supported apps are listed in the WinApps docs: Adobe, Office family, Visual Studio, etc.

### ISO management

- **`winapps-download-iso`** — downloads Tiny10 ISO to `~/.local/share/winapps/iso/` (NOT the Nix store).
- Idempotent: checks SHA256 hash before each download, skips if already verified.
- Configurable URL via `services.winapps.tiny10iso.url`, hash via `services.winapps.tiny10iso.sha256`.
- Default: archive.org download of Tiny10 Pro.
- To update the hash after downloading: `nix-prefetch-url --unpack "https://.../Tiny%20-%20W10%20Pro.iso"` then paste the result into the config.

### Configuration

`services.winapps.{windowsHostIP, windowsUser, windowsPassword, rdpScaling}` — defaults provided. Credentials can be stored securely (kwallet) and referenced in `/etc/winapps/winapps.conf` (module generates base config, user overrides go to `~/.config/winapps/winapps.conf`).

## Build & deploy

> **Builds work on a dirty git tree.** Nix evaluates the flake from the git index, so uncommitted changes to *tracked* files build fine (the "Git tree is dirty" warning is harmless). New files must be `git add`ed first — untracked files are invisible to the build and cause `Path '...' is not tracked by Git` errors.

> **The agent cannot run `sudo`** (needs interactive password/fingerprint), so it can't `nixos-rebuild switch` — the user runs that. The agent *can* still verify a build without root via `nixos-rebuild build --flake .#<host>` or `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`.

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
- **Role modules** (flat in `nixos/`): `cad.nix`, `gaming.nix`, `work.nix`, `family.nix`, `amd.nix`, `nvidia.nix`, `tailscale.nix`, `android.nix`, `npu.nix`, `reverse_engineering.nix`, `misc/dslr-webcam.nix`, `winapps.nix`, etc. — composed per host by listing them in `flake.nix` under each host's `modules`.
- **Overlays**: `additions` (custom pkgs from `pkgs/`), `modifications` (empty, for overrides), `unstable-packages` (exposes nixpkgs-unstable as `pkgs.unstable`).
- **Home-manager**: full profile at `home-manager/traverseda/home.nix`, minimal at `home-manager/traverseda/home-minimal.nix`.

## OpenCode MCP servers & plugins

- **tavily** — remote MCP (`https://mcp.tavily.com`) for web search.
- **openrouter_image** — local MCP (`pkgs/openrouter-image-mcp`) that analyzes images via the OpenRouter vision model. Needs `OPENROUTER_API_KEY`.
- **playwright** — local MCP (`pkgs/playwright-mcp`) for browser automation and screenshots. Uses nix-packaged browsers via `PLAYWRIGHT_BROWSERS_PATH`.
- **opencode-vision** plugin — intercepts pasted images for text-only models (see AGENTS.md below for details).
## Key conventions

- **Formatter is `alejandra`** (set in `flake.nix` outputs). Run `nix fmt` before committing.
- **`wallpapers/` uses Git LFS** (see `.gitattributes`). Make sure LFS is available when cloning.
- **`result/` symlink is gitignored** — it points to the last nix build output.
- **`allowUnfree = true`** is set globally in `configuration.nix`.
- **`mainUser`** specialArg is used for non-traverseda hosts (e.g. `selaphiel` → `mainUser = "ingrid"`).

## Agent file editing workflow

The `edit` tool requires *exact* matching of strings (whitespace and all). Nix files use tabs for indentation, and `nix fmt` can realign strings, making substrings impossible to match after formatting.

- **Small changes** (1-3 lines, same section): `read` → `edit`. Only if the change is truly atomic and the file hasn't been reformatted since you last read it.
- **Complex/multi-section changes**: `read` the file → `write` the *entire* file with your modifications. Never patch complex files piece-by-piece.
- **After any `write`**: always run `nix fmt` to realign tabs and spacing. This resets the file so you can use `edit` again if needed on the *formatted* version.

### Nix string escaping

- Inside Nix heredocs `'' ... ''`, pure shell `$var` is safe (no Nix interpolation).
- Nix `${attr}` interpolation **always** activates inside `'' ''`.
- To avoid accidental Nix interpolation in shell scripts, use `${${attr}}` or write the script logic in a separate file.

## Home-manager on non-NixOS

```bash
home-manager switch --impure --flake "git+https://codeberg.org/traverseda/nixos-config.git?ref=main#generic-minimal" \
  --extra-experimental-features nix-command --extra-experimental-features flakes
```

## OpenCode configuration

- **OpenCode is configured declaratively via home-manager** in `home-manager/traverseda/opencode.nix`. It writes `~/.config/opencode/opencode.json` on `home-manager switch` — do NOT edit that file directly (it's generated, edits get overwritten).
- Model/provider vars (`AI_STRONG_MODEL`, `AI_WEAK_MODEL`, `AI_VISION_MODEL`, `*_PROVIDER`) live in `home-manager/traverseda/home.nix` and are referenced from the opencode config.
- Custom opencode packages live in `pkgs/` (e.g. `pkgs/opencode-vision`, `pkgs/openrouter-image-mcp`), registered in `pkgs/default.nix`.
- Vision for text-only models: the `opencode-vision` plugin (DavidEasden's, packaged in `pkgs/opencode-vision`) intercepts pasted images and routes them to the `openrouter_image` MCP server (`pkgs/openrouter-image-mcp`), which analyzes them via the OpenRouter vision model (`AI_VISION_MODEL`). Needs `OPENROUTER_API_KEY` available as an env var (e.g. stored in kwallet so `load-kwallet-env` exports it). The plugin's config (which models to intercept + MCP tool name) is generated to `~/.config/opencode/opencode-vision.json` from `home-manager/traverseda/opencode.nix`.

## Flake inputs

| Input | Purpose |
|---|---|
| `nixpkgs` | stable (`nixos-26.05`) |
| `nixpkgs-unstable` | exposed as `pkgs.unstable` via overlay |
| `home-manager` | `release-26.05` |
| `chaotic` | catchyOS kernel (`chaotic-cx/nyx/nyxpkgs-unstable`) |
| `nixvim` | neovim config (`nixos-26.05`) |
| `plasma-manager` | KDE Plasma config |
| `nix-index-database` | `nix-locate` database |
| `winapps` | Windows app bridging via RDP (github:winapps-org/winapps) |
