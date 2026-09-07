{
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation {
  pname = "firefox-mcp-profile";
  version = "1.74.0";

  src = fetchurl {
    url = "https://github.com/gorhill/uBlock/releases/download/1.74.0/uBlock0_1.74.0.firefox.signed.xpi";
    sha256 = "0lhngmads52qj5732rmhsn10yrxyscrw6zrzhr2vmjb88kbmcmqp";
  };

  unpackPhase = "true";

  installPhase = ''
    mkdir -p "$out/extensions/ublock0@raymondhill.net"
    cp "$src" "$out/extensions/ublock0@raymondhill.net/extension.xpi"

    mkdir -p "$out/prefs.d"
    cat > "$out/prefs.d/ublock-preferences.js" << 'EOF'
    user_pref("extensions.webrequest.disable-cache", true);
    EOF

    mkdir -p "$out/defaults/pref"
    cp "$out/prefs.d/ublock-preferences.js" "$out/defaults/pref/override.js"

    cat > "$out/prefs.js" << 'EOF'
    user_pref("browser.startup.page", 0);
    user_pref("browser.shell.checkDefaultBrowser", false);
    user_pref("browser.download.folderList", 2);
    user_pref("browser.download.dir", "/tmp");
    user_pref("devtools.debugger.prompt-connection", false);
    user_pref("media.autoplay.default", 5);
    user_pref("plugin.default_plugin_disabled", false);
    user_pref("plugin.state.flash", 0);
    EOF
  '';

  preferLocalBuild = true;

  meta = {
    description = "Firefox profile directory with uBlock Origin for Playwright MCP";
    license = "GPL-3.0-or-later";
    platforms = ["x86_64-linux" "aarch64-linux"];
  };
}
