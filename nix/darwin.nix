{ inputs, lib, pkgs, ... }:
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

      # AeroSpace 公式ガイドの推奨値。spans-displays は「ディスプレイごとに個別の
      # 操作スペース」を無効化する（反映には再ログインが必要）。
      spaces.spans-displays = true;
      dock.expose-group-apps = true;

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

  # 設定はモジュールが settings から TOML を生成して --config-path で渡すため、
  # mise/dotfiles ではなくここで一元管理する。起動は launchd が担う。
  services.aerospace =
    let
      # ワークスペース名 → 自動で送るアプリの Bundle ID。
      # ctrl+opt+<小文字> で移動、ctrl+opt+shift+<小文字> でフォーカス中のウィンドウを送る。
      workspaces = {
        T = [ "com.raphaelamorim.rio" ];
        B = [ "app.zen-browser.zen" ];
        C = [
          "com.tinyspeck.slackmacgap"
          "com.hnc.DiscordCanary"
        ];
        M = [ "md.obsidian" ];
      };
      # 上のどれにも当てはまらないウィンドウの受け皿。タイル分割せず floating で置く。
      fallback = "O";
      # 受け皿へ送ると表示中でないワークスペースに隠れてしまう認証ダイアログ等の Bundle ID。
      # ワークスペースを移さず、いま見ている画面に floating で出す。
      floatInPlace = [
        "com.1password.1password"
        "com.apple.SecurityAgent" # sudo (pam_tid) の Touch ID などの認証ダイアログ
      ];
    in
    {
      enable = true;
      settings = {
        mode.main.binding = lib.concatMapAttrs (
          ws: _:
          let
            key = lib.toLower ws;
          in
          {
            "ctrl-alt-${key}" = "workspace ${ws}";
            "ctrl-alt-shift-${key}" = "move-node-to-workspace ${ws}";
          }
        ) (workspaces // { ${fallback} = [ ]; });
        # 最初に当てはまったルールで止まるので、受け皿は必ず最後に置く。
        on-window-detected =
          map (id: {
            "if".app-id = id;
            run = "layout floating";
          }) floatInPlace
          ++ lib.concatLists (
            lib.mapAttrsToList (
              ws:
              map (id: {
                "if".app-id = id;
                run = "move-node-to-workspace ${ws}";
              })
            ) workspaces
          )
          ++ [
            {
              run = [
                "layout floating"
                "move-node-to-workspace ${fallback}"
              ];
            }
          ];
      };
    };

  # herdr のペインは GUI セッションから切り離されたサーバー配下で動くため、
  # pam_reattach で再接続しないと pam_tid の Touch ID が失敗する。
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

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
    # 揃わないため、Monaspace + IBM Plex Sans JP + Nerd Fonts の合成フォントを使う。
    pkgs.moralerspace
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
