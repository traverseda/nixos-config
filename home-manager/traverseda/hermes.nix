{ config, pkgs, inputs, ... }:

let
  hermes-wrapped = pkgs.symlinkJoin {
    name = "hermes-agent-wrapped";
    paths = [ inputs.hermes-agent.packages.${pkgs.system}.default ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/hermes \
        --prefix LD_LIBRARY_PATH : "${pkgs.portaudio}/lib" \
        --run '
          if [ "$PWD" = "$HOME" ]; then
            cd "$HOME/hermes" 2>/dev/null || true
          fi
          if [ -z "$HERMES_TUI" ]; then
            export HERMES_TUI=1
          fi
        '
    '';
  };
in
{
  home.packages = [
    hermes-wrapped
    pkgs.portaudio
    pkgs.espeak
  ];
}
