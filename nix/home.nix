{ inputs, pkgs, ... }:
let
  # グローバルに使うツールは unstable から取る。stable 26.05 では
  # llvmPackages_22.clang-tools が 22.1.5、gopls が 0.22.0 で、置き換え前の
  # mise の版に届かない。copilot-language-server だけ unfree なので
  # legacyPackages では評価できず、predicate で当該パッケージのみ許可する。
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfreePredicate = p: pkgs.lib.getName p == "copilot-language-server";
  };
  misePackage = unstable.mise;

  # gotools は goimports のほかに bundle / stringer / play / stress など汎用名の
  # バイナリを 45 個撒く。bundle は ruby のものと衝突して profile が作れないので、
  # conform が使う goimports だけを取り出す。単体パッケージは nixpkgs に無い。
  goimports = pkgs.runCommand "goimports-${unstable.gotools.version}" { } ''
    mkdir -p "$out/bin"
    ln -s ${unstable.gotools}/bin/goimports "$out/bin/goimports"
  '';

  # Neovim が解決する LSP / リンタ / フォーマッタの実体。npm 製サーバの
  # `#!/usr/bin/env node` を nixpkgs が絶対 node パスに書き換えるため、
  # プロジェクトが古い node を pin していても影響を受けない。
  devTools = [
    unstable.basedpyright
    unstable.copilot-language-server
    unstable.gopls
    unstable.llvmPackages_22.clang-tools # clangd + clang-format + clang-tidy を同一版で供給
    unstable.lua-language-server
    unstable.ruby-lsp
    unstable.tailwindcss-language-server
    unstable.typescript-language-server
    unstable.vscode-langservers-extracted # jsonls / cssls / html / eslint の 4 本
    unstable.yaml-language-server
    unstable.biome
    unstable.golangci-lint
    unstable.ruff
    unstable.yamllint
    unstable.gofumpt
    goimports
    unstable.prettier
    unstable.stylua
  ];

  # 日常 CLI とエディタ。neovim は provider wrapper が付かない unwrapped を使う。
  # yq は yq-go（pkgs.yq は別物の Python 実装）、delta は git-delta ではなく delta。
  cliTools = [
    unstable.bat
    unstable.delta
    unstable.eza
    unstable.fd
    unstable.fzf
    unstable.gh
    unstable.ghq
    unstable.jq
    unstable.lazygit
    unstable.neovim-unwrapped
    unstable.ripgrep
    unstable.starship
    unstable.tree-sitter
    unstable.yq-go
    unstable.zoxide
  ];

  # プロジェクト外のファイル向けフォールバック。プロジェクトが mise.toml /
  # .node-version / Gemfile / rust-toolchain.toml で版を pin していれば、mise が
  # installs を PATH 前方に置くのでそちらが勝つ（sheldon は hook-env モードで
  # activate するので、宣言が無いディレクトリではここまでフォールスルーする）。
  runtimes = [
    unstable.nodejs_24
    unstable.python314
    unstable.go
    unstable.ruby_4_0
    unstable.rustc
    unstable.cargo
    unstable.rustfmt # conform の rustfmt
    unstable.clippy # rust_analyzer の check.command
    unstable.rust-analyzer
  ];
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
    pkgs.postgresql_18
  ] ++ devTools ++ cliTools ++ runtimes ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
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
