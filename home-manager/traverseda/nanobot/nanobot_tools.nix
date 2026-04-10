{ config, pkgs, inputs, lib, ... }:
let

  #ToDo: Most of these security features barely work. Nanobot can see itself in /proc and thus see a bunch of extra env vars.
  # All private env vars are getting passed to MCP servers.
  # Generally just firejail's approach of starting from a pretty open shell and then locking it down is not great.
  python = pkgs.python313;

  baseSet = pkgs.callPackage inputs.pyproject-nix.build.packages {
    inherit python;
  };

  mkUvScriptEnv = scriptFile:
    let
      script = inputs.uv2nix.lib.scripts.loadScript {
        script = ./tools + "/${scriptFile}";
      };
      overlay = script.mkOverlay { sourcePreference = "wheel"; };
      pythonSet = baseSet.overrideScope (
        lib.composeManyExtensions [
          inputs.pyproject-build-systems.overlays.wheel
          overlay
        ]
      );
    in
      script.mkVirtualEnv { inherit pythonSet; };

  mkMcpService = name: tool:
    let
      envFlags = lib.concatStringsSep " \\\n          "
        (map (v: "--env=${v}=\"\$${v}\"") tool.env);

      execScript = pkgs.writeShellScript "mcp-${name}-exec" ''
        exec /run/wrappers/bin/firejail \
          ${lib.concatStringsSep " \\\n          " tool.firejailArgs} \
          ${envFlags} \
          -- ${tool.package}/bin/${tool.bin}
      '';
    in
    {
      Unit = {
        Description = "Sandboxed MCP gateway for ${name}";
        After       = [ "graphical-session.target" ];
        PartOf      = [ "mcp.target" ];
      };
      Service = {
        Type      = "simple";
        ExecStart = pkgs.writeShellScript "mcp-${name}-service" ''
          mkdir -p "$XDG_RUNTIME_DIR/mcp"
          rm -f "$XDG_RUNTIME_DIR/mcp/${name}.sock"
          exec ${pkgs.socat}/bin/socat \
            "UNIX-LISTEN:$XDG_RUNTIME_DIR/mcp/${name}.sock,mode=600,fork" \
            "EXEC:${pkgs.bash}/bin/bash --login ${execScript}"
        '';
        RuntimeDirectory     = "mcp";
        RuntimeDirectoryMode = "0700";
        Restart              = "on-failure";
        RestartSec           = "2s";
      };
      Install.WantedBy = [ "mcp.target" ];
    };

  mcpConnect = pkgs.writeShellScriptBin "mcp-connect" ''
    name="$1"
    if [[ -z "$name" ]]; then
      echo "Usage: mcp-connect <server-name>" >&2
      exit 1
    fi
    exec ${pkgs.socat}/bin/socat \
      STDIO \
      "UNIX-CONNECT:/run/user/$(id -u)/mcp/$name.sock"
  '';

  nanobotEnv = mkUvScriptEnv "nanobot.py";

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
  _module.args = { inherit mkUvScriptEnv mkMcpService mcpConnect nanobotSandboxed; };
}
