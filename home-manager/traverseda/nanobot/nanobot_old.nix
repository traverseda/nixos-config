{ config, pkgs, inputs, lib, mkUvScriptEnv, ... }:
let

  #ToDo: Most of these security features barely work. Nanobot can see itself in /proc and thus see a bunch of extra env vars.
  # All private env vars are getting passed to MCP servers.
  # Generally just firejail's approach of starting from a pretty open shell and then locking it down is not great.



  nanobotEnv = mkUvScriptEnv ./tools/nanobot.py [ ];

  nanobotSandboxed = pkgs.writeShellScriptBin "nanobot" ''
    # Run as an interactive login shell to ensure KWallet env vars are sourced
    # and that the shell initialization (which might have interactive guards) is fully processed.
    exec ${pkgs.bash}/bin/bash -li -c '
      exec /run/wrappers/bin/firejail \
        --caps.drop=all \
        --env=XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR}" \
        --env=OPENROUTER_API_KEY="''${OPENROUTER_API_KEY}" \
        --whitelist="${config.home.homeDirectory}/.nanobot" \
        --whitelist="$XDG_RUNTIME_DIR/mcp" \
        --no3d --nodvd --nosound --notv --nou2f --novideo \
        -- ${nanobotEnv}/bin/nanobot "$@"
    ' "nanobot" "$@"
  '';

in
{

  _module.args = { inherit nanobotSandboxed; };
}
