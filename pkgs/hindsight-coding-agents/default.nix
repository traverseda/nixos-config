{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
}:
buildNpmPackage rec {
  pname = "hindsight-coding-agents";
  version = "0.8.2";

  src = fetchFromGitHub {
    owner = "vectorize-io";
    repo = "hindsight";
    rev = "integrations/coding-agents/v${version}";
    hash = "sha256-oU/YGmFT7e1hpztiEcg0L3NaUG0pTXd88TyKrg5NHJA=";
  };
  sourceRoot = "${src.name}/hindsight-integrations/coding-agents";

  # {host} and {gitRoot} retain-stamp placeholders, so memories in the shared
  # hermes bank say which machine and checkout they came from.
  # hindsight_define_topic_page: standing pages on topics that aren't one
  # initiative (design principles, platform overviews), in a Topics folder.
  patches = [
    ./host-and-root-placeholders.patch
    ./topic-pages-tool.patch
  ];

  npmDepsHash = "sha256-C3SJYG8llILaF8OlbS62YP8Vsme4M5e/14el5OFe6zc=";

  # Every entry point under dist/ is a self-contained bundle (node built-ins
  # only), loaded by absolute path: opencode's plugin list, Claude Code's
  # hooks and the MCP server all point into $out/lib/node_modules/....
  meta = {
    description = "Hindsight long-term memory for coding agents (Claude Code, opencode, ...)";
    homepage = "https://github.com/vectorize-io/hindsight/tree/main/hindsight-integrations/coding-agents";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
