# Long-term memory for the coding agents (Claude Code, opencode), backed by
# the Hindsight server on hermes. Everything goes into hermes's own central
# `hermes` bank, so provenance lives in tags instead of in the bank name:
#
#   host:<hostname>                which machine the session ran on
#   repo:<hostname>:<repo root>    the checkout, as a pointer you can cd to
#   project:<repo name>            the same repo across machines
#   session:<agent session id>     one agent session
#
# {host} and {gitRoot} come from a local patch (pkgs/hindsight-coding-agents).
# The API key is HINDSIGHT_API_TOKEN from kwallet (load-kwallet-env); it is
# never written to the store.
{
  config,
  lib,
  pkgs,
  ...
}: let
  root = "${pkgs.hindsight-coding-agents}/lib/node_modules/@vectorize-io/hindsight-coding-agents";
  node = "${pkgs.nodejs}/bin/node";
  hook = entry: "${node} ${root}/dist/${entry}";
in {
  home.file.".hindsight/coding-agent.json".text = builtins.toJSON {
    apiUrl = "https://hindsight-api.0u0.ca";
    bankId = "hermes";

    # The hermes bank belongs to the hermes agent: don't reshape its
    # strategies/missions, and don't seed it with per-repo machinery (git
    # history, codebase surveys, the five coding knowledge pages).
    manageBankConfig = false;
    autoSeed = false;
    gitIngest = "none";
    codebaseSurvey = false;
    pages = {
      "Component map" = false;
      "Core concepts" = false;
      "Conventions and patterns" = false;
      "Key decisions and rationale" = false;
      "Initiatives and enhancements" = false;
    };
    # Store path; the self-updater only replaces npx installs anyway.
    autoUpdate = false;

    retainTags = [
      "host:{host}"
      "repo:{host}:{gitRoot}"
      "project:{gitProject}"
      "session:{sessionId}"
    ];
    retainMetadata = {
      host = "{host}";
      repo_path = "{gitRoot}";
      repo = "{gitProject}";
      session_id = "{sessionId}";
    };
    # Extraction reads this, so facts come out host-qualified ("on azrael,
    # ...") rather than as if they held on every machine. The first part is
    # the plugin's default context, kept as is.
    retainContext =
      "conversation between the user and you (the coding agent): user turns are the user's words and "
      + "decisions, assistant turns are yours. When an assistant turn says something is fixed, passes or "
      + "works, record it as the agent's claim (\"the agent reported X fixed\"), not as an established fact. "
      + "This session ran on the machine {host}, in the checkout {gitRoot} (repo {gitProject}). "
      + "Facts about the machine, its hardware, installed software, paths or running services hold for "
      + "{host} only: state them as being about {host}.";
    toolGuideExtra =
      "This memory bank is shared by every machine and agent (and by the hermes assistant). "
      + "Memories are tagged host:<name> and repo:<host>:<path>. Facts about a machine hold for that "
      + "host only: run `hostname` before acting on one, and treat another host's paths, hardware or "
      + "services as not applying here. Memory is a past record, not current state: verify against "
      + "the code before acting on it.";
  };

  programs.opencode.settings.plugin = ["file://${root}/dist/index.js"];

  home.file.".claude/skills/hindsight-coding-agent".source = "${root}/skill";

  # Claude Code keeps hooks in ~/.claude/settings.json and user MCP servers in
  # ~/.claude.json, both of which it rewrites itself, so they can't be
  # home-manager symlinks. Merge our entries in instead: anything pointing
  # into a hindsight-coding-agents package is ours and gets replaced, so a
  # package bump repoints it and nothing else in the files is touched.
  home.activation.hindsightClaudeCode = lib.hm.dag.entryAfter ["writeBoundary"] ''
    merge() {
      local file=$1; shift
      [ -e "$file" ] || echo '{}' > "$file"
      local tmp
      tmp=$(mktemp "$file.XXXXXX")
      if ${pkgs.jq}/bin/jq "$@" "$file" > "$tmp" && ! cmp -s "$tmp" "$file"; then
        chmod --reference="$file" "$tmp"
        run mv "$tmp" "$file"
      else
        rm -f "$tmp"
      fi
    }

    merge "$HOME/.claude/settings.json" \
      --arg ss ${lib.escapeShellArg (hook "claude-sessionstart-hook.js")} \
      --arg prompt ${lib.escapeShellArg (hook "claude-hook.js")} \
      --arg stop ${lib.escapeShellArg (hook "claude-stop-hook.js")} '
      def ours: (.command // "") | test("hindsight-coding-agents");
      def set($cmd; $timeout):
        ((. // []) | map(.hooks |= map(select(ours | not))) | map(select(.hooks | length > 0)))
        + [{hooks: [{type: "command", command: $cmd, timeout: $timeout}]}];
      .hooks.SessionStart |= set($ss; 30)
      | .hooks.UserPromptSubmit |= set($prompt; 30)
      | .hooks.Stop |= set($stop; 60)
    '

    merge "$HOME/.claude.json" \
      --arg node ${lib.escapeShellArg node} \
      --arg server ${lib.escapeShellArg "${root}/dist/mcp-server.js"} '
      .mcpServers.hindsight = {
        type: "stdio",
        command: $node,
        args: [$server],
        env: {HINDSIGHT_MCP_HARNESS: "claude-code"}
      }
    '
  '';
}
