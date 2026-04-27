{ config, pkgs, inputs, lib, mkUvScriptEnv, ... }:
let


  nanobotEnv = mkUvScriptEnv ./tools/nanobot.py [ ];

  nanobotSandboxed = pkgs.writeShellScriptBin "nanobot" ''
        exec ${pkgs.bash}/bin/bash -li -c '
          exec ${pkgs.bubblewrap}/bin/bwrap \
            --unshare-all --die-with-parent \
            --setenv OPENROUTER_API_KEY "''${OPENROUTER_API_KEY}" \
            --bind "${config.home.homeDirectory}/.nanobot/config.json" "${config.home.homeDirectory}/.nanobot/config.json" \
            --bind "${config.home.homeDirectory}/.nanobot/workspace" "/workspace" \
            --bind "''${XDG_RUNTIME_DIR}/mcp/" "/mcp/" \
            --ro-bind /etc/resolv.conf /etc/resolv.conf \
            --ro-bind /nix /nix \
            --share-net \
            -- ${nanobotEnv}/bin/nanobot "$@"
        ' "nanobot" "$@"
      '';

in
{

  _module.args = { inherit nanobotSandboxed; };
}
