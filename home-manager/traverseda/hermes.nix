{ config, pkgs, inputs, ... }:

let
  hermes-bin = "${inputs.hermes-agent.packages.agent.packages.${pkgs.system}.default}/bin/hermes";

  # Environment variables to pass through into the bwrap sandbox.
  # Add new entries here as needed — they'll be set via --setenv.
  passEnv = [
    "OPENROUTER_API_KEY"
    "HOME_ASSISTANT_API_KEY"
    "TAVILY_API_KEY"
  ];

  # Launcher script: loads API keys from kwallet, then execs the bwrap-wrapped hermes.
  # Used by the systemd user service so env vars are available even without a login shell.
  hermes-launcher = pkgs.writeShellScriptBin "hermes-launcher" ''
    set -euo pipefail
    eval "$(load-kwallet-env)"
    exec hermes "$@"
  '';

in {
  home.packages = [
    (pkgs.writeShellScriptBin "hermes" ''
      set -euo pipefail

      WORKSPACE="/home/traverseda/0u0/hermes"

      #
      # Mount layout for the AI agent inside the sandbox:
      #
      # /etc/ssl/certs/  — On NixOS, these are symlinks to
      #   /etc/static/ssl/certs/. Mounting /etc/static/ lets all cert
      #   symlinks resolve naturally.
      #
      # /etc/static/ — NixOS-generated config files referenced by
      #   symlinks from /etc/. Includes CA certs and other generated
      #   configs.
      #
      # /run/current-system/ — NixOS system generation. Puts `nix`
      #   at /run/current-system/sw/bin/nix plus the rest of the
      #   system PATH. Needed for `nix build`, `nix shell`, etc.
      #
      # /nix/var/nix/daemon-socket — Nix daemon socket. Required
      #   whenever you run any `nix` command.
      #
      # /nix/store — Everything (hermes binary, python, curl, packages)
      #   lives here. Read-only.
      #

      BWRAP_ARGS=(
        # Hermes runtime (logs, history, config, skills)
        --bind "$HOME/.hermes" "$HOME/.hermes"

        # DNS
        --ro-bind /etc/resolv.conf /etc/resolv.conf

        # Isolation
        --unshare-ipc
        --unshare-pid
        --unshare-uts
        --unshare-cgroup
        --die-with-parent

        # Nix store — all binaries live here
        --ro-bind /nix/store /nix/store

        # NixOS system generation — provides nix binary at /run/current-system/sw/bin/nix
        --ro-bind /run/current-system/ /run/current-system/

        # Compatibility shebang paths — uvx-installed scripts have #!/bin/sh or
        #!/usr/bin/env, but NixOS doesn't have /bin or /usr/bin
        --ro-bind /run/current-system/sw/bin /bin
        --ro-bind /run/current-system/sw/bin /usr/bin

        # Nix daemon socket — needed for `nix build`, `nix shell`, etc. inside sandbox
        --bind /nix/var/nix/daemon-socket /nix/var/nix/daemon-socket

        # NixOS-generated config (CA certs, etc.) — /etc/ symlinks resolve through this
        --ro-bind /etc/static/ /etc/static/

        # Nix config directory — so NIX_PATH=/etc/nix/path resolves nixpkgs for nix-shell
        --ro-bind /etc/static/nix /etc/nixx

        # OS interface
        --proc /proc
        --dev /dev
        --tmpfs /tmp

        # User workspace (scripts, data, CSV output)
        --bind "$WORKSPACE" "$WORKSPACE"

        --setenv HERMES_TUI "0"
        --setenv SSL_CERT_FILE "/etc/static/ssl/certs/ca-bundle.crt"
        --setenv NIX_REMOTE "daemon"
        --setenv NIX_CONF_DIR "/etc/static/nix"
        --setenv NIX_PATH "/etc/nix/path"
      )

      ${builtins.concatStringsSep "\n" (map (var: ''
        if [ -n "''${${var}+x}" ]; then
          BWRAP_ARGS+=(--setenv "${var}" "''${${var}}")
        fi
      '') passEnv)}

      if [ "$PWD" != "$HOME" ]; then
        BWRAP_ARGS+=(--bind "$PWD" "$PWD")
        BWRAP_ARGS+=(--chdir "$PWD")
      else
        BWRAP_ARGS+=(--chdir "$WORKSPACE")
      fi

      exec bwrap "''${BWRAP_ARGS[@]}" ${hermes-bin} "$@"
    '')
    pkgs.bubblewrap
    hermes-launcher
    # portaudio – required for voice mode
    pkgs.portaudio
  ];

  systemd.user.services.hermes = {
    Unit = {
      Description = "Hermes AI Agent";
      After = [ "graphical-session.target" ];
      Requires = [ "graphical-session.target" ];
      BindsTo = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${hermes-launcher}/bin/hermes-launcher gateway";
      Restart = "on-failure";
      RestartSec = 10;
      Environment = "HERMES_TUI=0";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
