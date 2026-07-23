{ inputs, pkgs, ... }:
{
  nixpkgs.hostPlatform = "aarch64-darwin";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system = {
    primaryUser = "uvu1";
    stateVersion = 6;

    defaults = {
      finder.AppleShowAllFiles = true;

      # Scroll Reverser: マウスのみ反転。GUI での変更は次回 switch で宣言値に戻る。
      CustomUserPreferences."com.pilotmoon.scroll-reverser" = {
        InvertScrollingOn = true;
        ReverseTrackpad = false;
      };
    };
  };

  users.users.uvu1.home = "/Users/uvu1";

  nix-homebrew = {
    enable = true;
    enableRosetta = false;
    mutableTaps = true;
    user = "uvu1";
  };

  homebrew = {
    enable = true;
    casks = [
      "1password"
      "adobe-creative-cloud"
      "cloudflare-warp"
      "discord@canary"
      "hiddenbar"
      "karabiner-elements"
      "microsoft-office"
      "obsidian"
      "readdle-spark"
      "scroll-reverser"
      "slack"
      "spotify"
      "wezterm@nightly"
      "zen@twilight"
      "zoom"
    ];
    onActivation = {
      autoUpdate = true;
      cleanup = "none";
      upgrade = true;
    };
  };

  fonts.packages = [
    pkgs.nerd-fonts.jetbrains-mono
  ];

  home-manager = {
    extraSpecialArgs = { inherit inputs; };
    useGlobalPkgs = true;
    useUserPackages = true;
    users.uvu1 = {
      imports = [ ./home.nix ];
      home.username = "uvu1";
      home.homeDirectory = "/Users/uvu1";
    };
  };
}
