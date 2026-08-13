{
  lib,
  fetchurl,
  python3,
}:
python3.pkgs.buildPythonApplication rec {
  pname = "opencode-vision";
  version = "2.1.0";
  pyproject = true;

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/75/af/5b33c40c57f202edc3f499f1c80c85c37cd19bbb75eaa76e07d536b3bd8f/opencode_vision-${version}.tar.gz";
    sha256 = "af7aa64b598cfa2432a0c481fc7117f0cb8f24f9f6f3db987ca206f9cf5bbad4";
  };

  nativeBuildInputs = [python3.pkgs.setuptools python3.pkgs.wheel];
  dependencies = [python3.pkgs.pillow];

  postPatch = ''
    cp ${./openrouter.py} opencode_vision/openrouter.py
    cp ${./providers-openrouter.py} opencode_vision/providers/openrouter.py
    sed -i '/from opencode_vision.providers import ollama/a from opencode_vision.providers import openrouter as _openrouter  # noqa: F401, E402' opencode_vision/providers/__init__.py
  '';

  pythonImportsCheck = ["opencode_vision" "opencode_vision.providers.openrouter"];

  meta = {
    description = "MCP vision server for OpenCode text-only models (Gemini Vision API + OCR)";
    homepage = "https://github.com/NickRivers1983/opencode-vision";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
