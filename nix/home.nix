{ config, inputs, pkgs, ... }:
let
  # グローバルに使うツールは unstable から取る。stable 26.05 では
  # llvmPackages_22.clang-tools が 22.1.5、gopls が 0.22.0 で、置き換え前の
  # mise の版に届かない。copilot-language-server と 1password-cli は unfree なので
  # legacyPackages では評価できず、predicate で当該パッケージのみ許可する。
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfreePredicate = p:
      builtins.elem (pkgs.lib.getName p) [
        "1password-cli"
        "copilot-language-server"
      ];
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

  # codelldb（Rust / C++ のデバッグアダプタ）。単体パッケージは無く VSCode 拡張として
  # だけ提供され、実行ファイルは share/vscode/extensions/.../adapter/codelldb に置かれる
  # ので bin に出ない。goimports と同じ形で必要な 1 本だけ取り出す。拡張ごと
  # home.packages に入れると同梱の lldb / lldb-server / python3.12 まで profile に
  # 出て衝突源になる。nixpkgs 側で liblldb を絶対パスに wrap 済みなので、
  # symlink 経由で起動しても liblldb を見失わない（DAP の initialize に success で応答）。
  codelldb = pkgs.runCommand "codelldb-${unstable.vscode-extensions.vadimcn.vscode-lldb.version}" { } ''
    mkdir -p "$out/bin"
    ln -s ${unstable.vscode-extensions.vadimcn.vscode-lldb}/share/vscode/extensions/vadimcn.vscode-lldb/adapter/codelldb \
      "$out/bin/codelldb"
  '';

  # nvim-dap のデバッグアダプタと neotest のテストランナー。どれも実行ファイル名が
  # 一意なので profile 衝突は無い。mise へ置かない理由は 2 つあり、
  # 1 つは「グローバルに使うツールは nix」という全体方針、もう 1 つは registry に
  # 短縮名が存在せず backend を手で選ぶ必要があること（delve は go backend の
  # ソースビルド、codelldb は .vsix を zip として展開、js-debug は供給経路なし）。
  # 版は nix でも落ちない: delve 1.27.0 / cargo-nextest 0.9.140 /
  # vscode-js-debug 1.117.0 / codelldb 1.12.2。
  debugTools = [
    unstable.delve # dlv。nvim-dap-go が `dlv dap -l` で DAP サーバとして起動する
    codelldb
    unstable.vscode-js-debug # bin/js-debug は dapDebugServer.js を node で起動するラッパ
    unstable.cargo-nextest # neotest-rust が `cargo nextest run` を呼ぶ
  ];

  # 日常 CLI とエディタ。neovim は provider wrapper が付かない unwrapped を使う。
  # yq は yq-go（pkgs.yq は別物の Python 実装）、delta は git-delta ではなく delta、
  # ykman は yubikey-manager、aws は awscli2（pkgs.awscli は v1）。
  cliTools = [
    unstable.awscli2
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
    unstable.saml2aws
    unstable.sshfs
    unstable.starship
    unstable.tree-sitter
    unstable.tmux
    unstable.yq-go
    unstable.yubikey-manager
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
  # Nix store は setuid にできない。FUSE のマウント補助は Nix の版を
  # /usr/local/bin に配置し、版が変わったときだけ sudo を使う。
  wslFuseSetup = pkgs.writeShellApplication {
    name = "wsl-fuse-setup";
    runtimeInputs = [ pkgs.coreutils pkgs.diffutils ];
    text = ''
      if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != --dry-run ]; }; then
        echo "Usage: wsl-fuse-setup [--dry-run]" >&2
        exit 2
      fi
      helper=${unstable.fuse3.bin}/bin/fusermount3
      target=/usr/local/bin/fusermount3
      if [ -L "$target" ]; then
        echo "Refusing to replace symlink: $target" >&2
        exit 1
      fi
      if [ -f "$target" ] && [ -u "$target" ] && [ "$(stat -c %u "$target")" = 0 ] && cmp -s "$helper" "$target"; then
        exit 0
      fi
      if [ "$#" -eq 1 ]; then
        echo "Would install Nix-managed fusermount3 to $target with setuid root"
        exit 0
      fi
      sudo install -o root -g root -m 4755 "$helper" "$target"
    '';
  };
  # 非 NixOS の WSL に、Nix 管理の CCID ドライバーと pcscd を接続する。
  # uaccess はログイン seat のない WSL では使えないため、所有者を明示する。
  wslYkmanRules = pkgs.writeText "70-wsl-ykman.rules" ''
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="1050", OWNER="${config.home.username}", MODE="0600"
    KERNEL=="hidraw*", ATTRS{idVendor}=="1050", OWNER="${config.home.username}", MODE="0600"
  '';
  wslYkmanService = pkgs.writeText "wsl-ykman-pcscd.service" ''
    [Unit]
    Description=PC/SC for YubiKey on WSL (Nix managed)
    After=systemd-udevd.service
    Conflicts=pcscd.service pcscd.socket

    [Service]
    Type=simple
    RuntimeDirectory=pcscd
    Environment=PCSCLITE_HP_DROPDIR=${unstable.ccid}/pcsc/drivers
    ExecStart=${unstable.pcsclite}/bin/pcscd --foreground --config ${pkgs.writeText "wsl-ykman-reader.conf" ""}
    Restart=on-failure

    [Install]
    WantedBy=multi-user.target
  '';
  wslYkmanSetup = pkgs.writeShellApplication {
    name = "wsl-ykman-setup";
    runtimeInputs = [ pkgs.coreutils pkgs.diffutils ];
    text = ''
      if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "$1" != --dry-run ]; }; then
        echo "Usage: wsl-ykman-setup [--dry-run]" >&2
        exit 2
      fi
      service=/etc/systemd/system/wsl-ykman-pcscd.service
      rules=/etc/udev/rules.d/70-wsl-ykman.rules
      changed=false
      for target in "$service" "$rules"; do
        if [ -L "$target" ]; then
          echo "Refusing to replace symlink: $target" >&2
          exit 1
        fi
      done
      if ! cmp -s ${wslYkmanService} "$service" || ! cmp -s ${wslYkmanRules} "$rules"; then
        changed=true
      fi
      if [ "$#" -eq 1 ]; then
        echo "Would install/update pcscd service and YubiKey udev rules: $changed"
        echo "Would enable and start wsl-ykman-pcscd.service"
        exit 0
      fi
      if systemctl is-active --quiet pcscd.service pcscd.socket; then
        echo "An existing pcscd is active; resolve it before enabling wsl-ykman-pcscd." >&2
        exit 1
      fi
      if "$changed"; then
        sudo install -D -o root -g root -m 0644 ${wslYkmanService} "$service"
        sudo install -D -o root -g root -m 0644 ${wslYkmanRules} "$rules"
        sudo systemctl daemon-reload
        sudo udevadm control --reload-rules
        sudo udevadm trigger --subsystem-match=usb --attr-match=idVendor=1050
        sudo udevadm trigger --subsystem-match=hidraw
        sudo systemctl restart wsl-ykman-pcscd.service
      fi
      if ! systemctl is-enabled --quiet wsl-ykman-pcscd.service || ! systemctl is-active --quiet wsl-ykman-pcscd.service; then
        sudo systemctl enable --now wsl-ykman-pcscd.service
      fi
    '';
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
    # pg gem 等の C 拡張が libpq-fe.h と pg_config を要求する。postgresql_18 は
    # outputsToInstall が ["out" "man"] で dev が profile に入らず、さらに nixpkgs は
    # out から pg_config を削除している（generic.nix の `rm "$out/bin/pg_config"`）。
    # libpq も outputsToInstall が ["out"] だけなので dev を明示する。
    pkgs.libpq
    pkgs.libpq.dev
    pkgs.libpq.pg_config
  ] ++ devTools ++ debugTools ++ cliTools ++ runtimes ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
    unstable._1password-cli
  ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [
    dotfilesUpdate
    wslFuseSetup
    wslYkmanSetup
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
    ".local/bin/ssh-keyscan" = {
      executable = true;
      text = ''
        #!/bin/sh
        exec ${pkgs.openssh}/bin/ssh-keyscan "$@"
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
