{pkgs}: let
  ublockXPI = pkgs.fetchurl {
    url = "https://github.com/gorhill/ublock/releases/download/1.74.0/uBlock0_1.74.0.firefox.signed.xpi";
    sha256 = "0lhngmads52qj5732rmhsn10yrxyscrw6zrzhr2vmjb88kbmcmqp";
  };
  extId = "ublock0@raymondhill.net";
  browsersPath = pkgs.playwright.browsers;

  # Extract XPI at build time using python3 from buildInputs
  extDir = pkgs.runCommand "${extId}-embedded" {buildInputs = [pkgs.python3];} ''
        mkdir -p "$out"
        TMP=$(mktemp -d)
        ${pkgs.python3}/bin/python3 -c '
    import zipfile, glob, os, shutil, sys
    xfi = sys.argv[1]
    tmp = sys.argv[2]
    out = sys.argv[3]
    with zipfile.ZipFile(xfi) as z:
        z.extractall(tmp)
    # XPI extracts to flat structure - copy everything to output
    for item in glob.glob(os.path.join(tmp, "*")):
        name = os.path.basename(item)
        dst = os.path.join(out, name)
        if os.path.isdir(item):
            shutil.copytree(item, dst, dirs_exist_ok=True)
        else:
            shutil.copy2(item, dst)
    ' "${ublockXPI}" "$TMP" "$out"
  '';

  # Wrapper: copies already-extracted extension files to writable profile
  wrapper = pkgs.writeShellScriptBin "playwright-mcp-firefox" ''
    PLAYWRIGHT_MCP_BROWSERS_PATH="${browsersPath}"
    PLAYWRIGHT_MCP_BROWSER="firefox"
    PROFILE_DIR="$HOME/.cache/playwright-mcp-firefox"
    LIBDIR="$(cd "$(dirname "$0")" && pwd)"
    mkdir -p "$PROFILE_DIR/extensions/ublock0@raymondhill.net"
    cp -r "$LIBDIR/lib/node_modules/playwright-mcp-internal/ublock0@raymondhill.net/"* \
      "$PROFILE_DIR/extensions/ublock0@raymondhill.net/" 2>/dev/null || true
    export PLAYWRIGHT_MCP_USER_DATA_DIR="$PROFILE_DIR"
    exec ${pkgs.nodejs}/bin/node "$LIBDIR/lib/node_modules/playwright-mcp-internal/cli.js" "$@"
  '';
in
  pkgs.stdenv.mkDerivation {
    name = "playwright-mcp-firefox-${pkgs.playwright-mcp.version}";
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;

    postInstall = ''
      mkdir -p "$out/bin" "$out/lib/node_modules/playwright-mcp-internal/ublock0@raymondhill.net"
      cp -rL "${pkgs.playwright-mcp}/lib/node_modules/"* "$out/lib/node_modules/"
      chmod -R u+w "$out/lib/node_modules/"

      # Copy extracted uBlock extension files into MCP data dir
      cp -rL ${extDir}/* "$out/lib/node_modules/playwright-mcp-internal/ublock0@raymondhill.net/"

      cp -L ${ublockXPI} "$out/lib/node_modules/playwright-mcp-internal/uBlock0_firefox.signed.xpi"
      cp -L ${wrapper}/bin/playwright-mcp-firefox "$out/bin/playwright-mcp-firefox"
    '';

    preferLocalBuild = true;
  }
