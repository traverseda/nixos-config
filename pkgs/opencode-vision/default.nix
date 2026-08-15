{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
}:
buildNpmPackage rec {
  pname = "opencode-vision";
  version = "1.3.0";

  src = fetchFromGitHub {
    owner = "DavidEasden";
    repo = "opencode-vision";
    rev = "bc24cc84658a79c1204717646cf32701b1bba2c0";
    hash = "sha256-K5K8WVvc6CErJHusCky7Ho9wOFES5jHMjrWth7ZTvpc=";
  };

  npmDepsHash = "sha256-4cBmi3hYCLD0IyTjwtRvqtKXO1gta4pEg1MtHIr1S7U=";

  # The plugin only type-imports @opencode-ai/*; the built dist is
  # self-contained (node built-ins only), so expose it as dist/index.js.
  postInstall = ''
    mkdir -p $out/dist
    cp -r $out/lib/node_modules/opencode-vision/dist/. $out/dist/
  '';

  meta = {
    description = "OpenCode plugin giving vision support to text-only models";
    homepage = "https://github.com/DavidEasden/opencode-vision";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.linux;
  };
}
