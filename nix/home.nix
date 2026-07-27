{ inputs, pkgs, ... }:
let
  misePackage = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mise;
  dotfilesUpdate = pkgs.writeShellApplication {
    name = "dotfiles-update";
    runtimeInputs = [
      pkgs.git
      misePackage
    ];
    text = ''
      export PATH="$HOME/.local/share/mise/shims:$PATH"
    '' + builtins.readFile ../scripts/update-wsl.sh;
  };
in
{
  home.stateVersion = "26.05";

  home.packages = [
    pkgs.curl
    pkgs.git
    misePackage
    pkgs.sheldon
    pkgs.zsh
    pkgs.podman
    pkgs.docker-compose # podman compose のプロバイダ（Docker API ソケット経由で接続）
  ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
    dotfilesUpdate
    pkgs.gcc
    pkgs.wl-clipboard
    pkgs.passt
  ];

  home.file = pkgs.lib.optionalAttrs pkgs.stdenv.isLinux {
    # WSLの日本語文字化け対策。programs.zsh 未使用で hm-session-vars.sh が
    # 読まれないため、zshが最初に読む .zshenv でロケールを明示する。
    # en_US.UTF-8 は Nix パッチ済み glibc しか LOCALE_ARCHIVE から解決できず、
    # システム(Arch)glibc にリンクされた mise 導入ツールや coreutils は
    # LOCALE_ARCHIVE を無視して C にフォールバックし日本語を化けさせる。
    # C.UTF-8 は Nix/システム両方の glibc に組み込みで存在し archive 不要のため、
    # 全プロセスで一貫して UTF-8 になる。LOCALE_ARCHIVE は名前付きロケールを
    # 要求する Nix ツール向けに残す。
    ".zshenv".text = ''
      export LOCALE_ARCHIVE="${pkgs.glibcLocales}/lib/locale/locale-archive"
      export LANG=C.UTF-8
    '';

    # 非NixOSのArchではNixのpodmanが/etc/containers/policy.jsonを持たず
    # `podman pull`が失敗するため、ユーザー設定として宣言する。
    ".config/containers/policy.json".text = ''
      { "default": [ { "type": "insecureAcceptAnything" } ] }
    '';
    ".config/containers/registries.conf".text = ''
      unqualified-search-registries = ["docker.io"]
    '';

    ".local/bin/ssh" = {
      executable = true;
      text = ''
        #!/bin/sh
        exec /mnt/c/Windows/System32/OpenSSH/ssh.exe "$@"
      '';
    };
    ".local/bin/ssh-keygen" = {
      executable = true;
      text = ''
        #!/bin/sh
        exec ${pkgs.openssh}/bin/ssh-keygen "$@"
      '';
    };
  };

  systemd.user = pkgs.lib.mkIf pkgs.stdenv.isLinux {
    # 非NixOSのArchではNixのpodmanが同梱するuser unitがsystemd探索パスに入らないため、
    # docker-compose（Docker APIクライアント）が繋ぐ podman.sock を宣言的に有効化する。
    # podman compose はこのソケットを DOCKER_HOST に自動設定して provider を呼ぶ。
    sockets.podman = {
      Unit = {
        Description = "Podman API Socket";
        Documentation = [ "man:podman-system-service(1)" ];
      };
      Socket = {
        ListenStream = "%t/podman/podman.sock";
        SocketMode = "0660";
      };
      Install.WantedBy = [ "sockets.target" ];
    };
    services.podman = {
      Unit = {
        Description = "Podman API Service";
        Requires = [ "podman.socket" ];
        After = [ "podman.socket" ];
        Documentation = [ "man:podman-system-service(1)" ];
        StartLimitIntervalSec = 0;
      };
      Service = {
        Delegate = true;
        Type = "exec";
        KillMode = "process";
        Environment = ''LOGGING="--log-level=info"'';
        # socket activation でリッスンFDを継承（アドレス指定なし）。
        ExecStart = "${pkgs.podman}/bin/podman $LOGGING system service";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };

  # プロジェクトの .envrc から flake devshell を自動で読み込む。
  # nix-direnv は devshell を GC root に登録し、再入時の再評価と
  # nix store GC による巻き添え削除（texlive 等の大きな closure）を防ぐ。
  # programs.zsh 未使用で HM の zsh integration が .zshrc に届かないため、
  # hook は mise/dotfiles/.config/sheldon/plugins.toml 側で入れる。
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = false;
  };

  programs.home-manager.enable = true;
}
