{ config, pkgs, inputs, ... }:

let
  hermes-bin = "${inputs.hermes-agent.packages.${pkgs.system}.default}/bin/hermes";

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

      BWRAP_ARGS=(
        # Directory writable (logs, history), but config.yaml read-only
        --bind "$HOME/.hermes" "$HOME/.hermes"
        #--ro-bind "$HOME/.hermes/config.yaml" "$HOME/.hermes/config.yaml"
        # DNS
        --ro-bind /etc/resolv.conf /etc/resolv.conf
        --unshare-ipc
        --unshare-pid
        --unshare-uts
        --unshare-cgroup
        --die-with-parent
        --ro-bind /nix/store /nix/store
        --ro-bind /run/current-system/ /run/current-system/
        --bind /nix/var/nix/daemon-socket /nix/var/nix/daemon-socket
        --proc /proc
        --dev /dev
        --tmpfs /tmp
        --bind "$WORKSPACE" "$WORKSPACE"
        --setenv HERMES_TUI "0"
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
