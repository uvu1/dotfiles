{ fetchurl, google-chrome, lib }:

# Google publishes Canary in its Linux APT repository. Reuse the Nixpkgs
# Chrome wrapper with the channel-specific paths in Google's package.
(google-chrome.override { withSymlink = false; }).overrideAttrs (old: {
  pname = "google-chrome-canary";
  version = "160.0.8177.0";

  src = fetchurl {
    url = "https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-canary/google-chrome-canary_160.0.8177.0-1_amd64.deb";
    hash = "sha256-xdpP+f68Jksosx+F7Kk0G4lU2nm+FrYkp4iPISA3uqM=";
  };

  installPhase = lib.replaceStrings
    [ "appname=chrome\n" "dist=stable\n" "com.google.Chrome.desktop" ]
    [ "appname=chrome-canary\n" "dist=canary\n" "com.google.Chrome.canary.desktop" ]
    old.installPhase;

  meta = old.meta // {
    description = "Google Chrome Canary for Linux";
    mainProgram = "google-chrome-canary";
    platforms = [ "x86_64-linux" ];
  };
})
