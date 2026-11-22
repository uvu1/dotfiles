{ fetchurl, firefox-bin-unwrapped, lib, wrapFirefox }:

let
  version = "1.25t";
  binaryName = "zen-twilight";
  unwrapped = firefox-bin-unwrapped.overrideAttrs (old: {
    pname = "${binaryName}-unwrapped";
    inherit version;

    # Zen replaces this official nightly asset. Update the hash together with
    # the build date when the upstream archive changes.
    src = fetchurl {
      url = "https://github.com/zen-browser/desktop/releases/download/twilight-1/zen.linux-x86_64.tar.xz";
      hash = "sha256-+OxcmUKrPIuM61RBmcIGVE+8CMKwZ1QWShY4jTkruzk="; # 2026-11-22
    };

    installPhase = ''
      runHook preInstall
      app="$out/lib/${binaryName}"
      mkdir -p "$app" "$out/bin"
      cp -r . "$app"
      mv "$app/zen" "$app/${binaryName}"
      ln -s ${binaryName} "$app/zen"
      ln -s "$app/${binaryName}" "$out/bin/${binaryName}"
      for size in 16 32 48 64 128; do
        install -Dm644 "browser/chrome/icons/default/default$size.png" \
          "$out/share/icons/hicolor/${"$"}{size}x$size/apps/${binaryName}.png"
      done
      runHook postInstall
    '';

    passthru = builtins.removeAttrs old.passthru [ "updateScript" ] // {
      inherit binaryName;
      applicationName = "Zen Browser Twilight";
      libName = binaryName;
    };

    meta = old.meta // {
      description = "Zen Browser Twilight for Linux";
      homepage = "https://zen-browser.app/";
      license = lib.licenses.mpl20;
      mainProgram = binaryName;
      platforms = [ "x86_64-linux" ];
    };
  });
in
# Select the FFmpeg ABI using the Gecko milestone in platform.ini.
wrapFirefox (unwrapped // { version = "160.0.1"; }) {
  inherit version;
  wmClass = "zen";
  extraPolicies.DisableAppUpdate = true;
}
