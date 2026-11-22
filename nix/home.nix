{ config, inputs, lib, pkgs, wsl, ... }:
let
  isNativeLinux = pkgs.stdenv.isLinux && !wsl;
  # グローバルに使うツールは unstable から取る。stable 26.05 では
  # llvmPackages_22.clang-tools が 22.1.5、gopls が 0.22.0 で、置き換え前の
  # mise の版に届かない。1Password と copilot-language-server は unfree なので
  # legacyPackages では評価できず、predicate で当該パッケージのみ許可する。
  unstable = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfreePredicate = p:
      builtins.elem (lib.getName p) [
        "1password-cli"
        "copilot-language-server"
      ];
  };
  misePackage = unstable.mise;

  # 0.13 の標準 SSH は ControlMaster を使うため、nvim の子プロセスだけ
  # Unix OpenSSH を優先する。WSL の通常の ssh ラッパは引き続き Windows 版。
  neovimPackage = inputs.neovim-nightly-overlay.packages.${pkgs.stdenv.hostPlatform.system}.default;
  neovim = pkgs.symlinkJoin {
    name = "neovim-${neovimPackage.version}";
    paths = [ neovimPackage ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/nvim" --prefix PATH : ${pkgs.lib.makeBinPath [ unstable.openssh ]}
    '';
  };

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
    neovim
    unstable.openssh
    unstable.ripgrep
    unstable.saml2aws
    unstable.sshfs
    unstable.starship
    unstable.tree-sitter
    unstable.tmux
    unstable.yq-go
    unstable.yubikey-manager
    unstable.zoxide
  ] ++ lib.optionals wsl [
    unstable.wsl2-ssh-agent
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
  winHome = "/mnt/c/Users/${config.home.username}";
  # WSL の ~/.local/bin に置くラッパ（名前 → 実体）。zsh は Windows の PATH を
  # 外すので（sheldon の wsl-local-bin）、名前で呼ぶ Windows コマンドはここに足す。
  wslCommands = {
    ssh = "/mnt/c/Windows/System32/OpenSSH/ssh.exe";
    ssh-keygen = "${pkgs.openssh}/bin/ssh-keygen";
    ssh-keyscan = "${pkgs.openssh}/bin/ssh-keyscan";
    "cmd.exe" = "/mnt/c/Windows/System32/cmd.exe";
    "explorer.exe" = "/mnt/c/Windows/explorer.exe";
    "powershell.exe" = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe";
    "sudo.exe" = "/mnt/c/Windows/System32/sudo.exe";
    "wsl.exe" = "/mnt/c/Windows/System32/wsl.exe";
    "usbipd.exe" = "/mnt/c/Program Files/usbipd-win/usbipd.exe";
    "winget.exe" = "${winHome}/AppData/Local/Microsoft/WindowsApps/winget.exe";
    "op.exe" = "${winHome}/AppData/Local/Microsoft/WinGet/Links/op.exe";
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
  ] ++ devTools ++ debugTools ++ cliTools ++ runtimes ++ lib.optionals (!wsl) [
    unstable._1password-cli
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    dotfilesUpdate
    pkgs.gcc
    pkgs.wl-clipboard
    pkgs.passt
  ] ++ lib.optionals wsl [
    wslFuseSetup
    wslYkmanSetup
  ];

  home.file = lib.optionalAttrs isNativeLinux {
    ".config/nix/nix.conf".text = "extra-experimental-features = nix-command flakes\n";
    ".zshenv".text = ''
      if [[ -r /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
        source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      fi
      if [[ -z ''${SSH_AUTH_SOCK:-} && -S "$HOME/.1password/agent.sock" ]]; then
        export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"
      fi
    '';
  } // lib.optionalAttrs pkgs.stdenv.isLinux {
    # 非NixOSのArchではNixのpodmanが/etc/containers/policy.jsonを持たない。
    ".config/containers/policy.json".text = ''
      { "default": [ { "type": "insecureAcceptAnything" } ] }
    '';
    ".config/containers/registries.conf".text = ''
      unqualified-search-registries = ["docker.io"]
    '';
  } // lib.optionalAttrs wsl ({
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
  } // pkgs.lib.mapAttrs' (name: target:
    pkgs.lib.nameValuePair ".local/bin/${name}" {
      executable = true;
      text = ''
        #!/bin/sh
        exec "${target}" "$@"
      '';
    }) wslCommands);

  # Windows側のconfigはDrvFSで0777に見え、Unix OpenSSHが拒否する。
  # 内容をNix storeに入れず、適用時だけUnix側へ0600で配置する。
  # Host節を残すことでNeovim標準のSSHホスト一覧からも選択できる。
  home.activation.wslSshConfig = lib.mkIf wsl (
    config.lib.dag.entryAfter [ "linkGeneration" ] ''
      if [[ -n "''${DRY_RUN_CMD:-}" ]]; then
        echo "Would regenerate ~/.ssh/config from Windows config (mode 0600; config.local overrides preserved)"
      else
        (
          ssh_config_source="${winHome}/.ssh/config"
          ssh_config_target="$HOME/.ssh/config"
          ssh_config_marker='# Generated by Home Manager from Windows SSH config; use config.local for Unix overrides.'
          if [[ ! -f "$ssh_config_source" || -L "$ssh_config_target" ]]; then
            echo "Cannot safely regenerate Unix SSH config" >&2
            exit 1
          fi
          if [[ -e "$ssh_config_target" ]] && [[ "$(${pkgs.coreutils}/bin/head -n 1 "$ssh_config_target")" != "$ssh_config_marker" ]]; then
            echo "Refusing to overwrite an unmanaged Unix SSH config; move its settings to ~/.ssh/config.local first" >&2
            exit 1
          fi
          ${pkgs.coreutils}/bin/install -d -m 0700 "$HOME/.ssh"
          ssh_config_tmp=$(${pkgs.coreutils}/bin/mktemp "$HOME/.ssh/config.XXXXXX")
          trap '${pkgs.coreutils}/bin/rm -f "$ssh_config_tmp"' EXIT
          {
            printf '%s\n' "$ssh_config_marker" 'Include ~/.ssh/config.local' 'Host *'
            ${pkgs.coreutils}/bin/cat "$ssh_config_source"
            printf '\n%s\n' 'Host *' \
              '  IdentityAgent ~/.ssh/wsl2-ssh-agent.sock' \
              '  UserKnownHostsFile ~/.ssh/known_hosts ${winHome}/.ssh/known_hosts'
          } > "$ssh_config_tmp"
          ${pkgs.coreutils}/bin/chmod 0600 "$ssh_config_tmp"
          ${pkgs.coreutils}/bin/mv "$ssh_config_tmp" "$ssh_config_target"
          trap - EXIT
        )
      fi
    ''
  );

  systemd.user = pkgs.lib.mkIf pkgs.stdenv.isLinux {
    services.wsl2-ssh-agent = lib.mkIf wsl {
      Unit.Description = "Windows OpenSSH agent bridge for Unix SSH";
      Service = {
        ExecStart = "${unstable.wsl2-ssh-agent}/bin/wsl2-ssh-agent --foreground --socket=${config.home.homeDirectory}/.ssh/wsl2-ssh-agent.sock --powershell-path=/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe";
        Restart = "on-failure";
        UMask = "0077";
      };
      Install.WantedBy = [ "default.target" ];
    };

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
