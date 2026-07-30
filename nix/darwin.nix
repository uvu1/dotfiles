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

      # 漢字が PingFang SC(簡体字) で描画されるのを防ぐ。CoreText のフォント
      # フォールバックは優先言語リスト全体を見るため、ja を2番目に置けば
      # UI は英語のまま Hiragino Sans が優先される。反映には再ログインが必要。
      CustomUserPreferences.NSGlobalDomain.AppleLanguages = [
        "en-JP"
        "ja-JP"
      ];

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
      "raycast"
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
