{
  stdenvNoCC,
  fetchurl,
  coreutils,
}:
stdenvNoCC.mkDerivation {
  name = "hindsight-coding-agents";
  version = "0.5.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/@vectorize-io/hindsight-coding-agents/-/hindsight-coding-agents-0.5.1.tgz";
    sha256 = "1cxy6pryzd8a5mkpligdvyxvkrqsk3mjirnldzw9nibazlz6n51l";
  };

  nativeBuildInputs = [coreutils];

  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    tar -xzf $src
    mv package/dist $out/
    runHook postInstall
  '';
}
