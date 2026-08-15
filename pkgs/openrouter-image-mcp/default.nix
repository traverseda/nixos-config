{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
}:
buildNpmPackage rec {
  pname = "openrouter-image-mcp";
  version = "1.0.13";

  src = fetchFromGitHub {
    owner = "JonathanJude";
    repo = "openrouter-image-mcp";
    rev = "c9c28d751b566cd927fda93601e0de84becbc52f";
    hash = "sha256-Z+MuntDjFlI5B8la8beJlAF40hQsIhh01+Y4heT7eMA=";
  };

  npmDepsHash = "sha256-tqGJdU6inDnVHV0vuQasCFbZhAM0yIn9XS8myIcgP7E=";

  # The repo's package-lock.json is missing `resolved` URLs for most packages,
  # which breaks the offline npm fetch. Regenerate it in the source.
  prePatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  meta = {
    description = "MCP server for image analysis via OpenRouter vision models";
    homepage = "https://github.com/JonathanJude/openrouter-image-mcp";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "openrouter-image-mcp";
  };
}
