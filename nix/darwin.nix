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

  services.tailscale.enable = true;

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
      "google-chrome@canary"
      "hiddenbar"
      "karabiner-elements"
      "macfuse"
      "microsoft-office"
      "obsidian"
      "raycast"
      "readdle-spark"
      # nixpkgs は stable / unstable とも 0.4.7 で upstream (0.5.x) から大きく遅れるため cask で入れる。
      "rio"
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
    # rio 用。rio はフォントごとの拡大率を調整できず、fallback のヒラギノは英字と高さが
    # 揃わないため、JetBrains Mono + BIZ UD ゴシック + Nerd Fonts の合成フォントを使う。
    pkgs.udev-gothic-nf
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
