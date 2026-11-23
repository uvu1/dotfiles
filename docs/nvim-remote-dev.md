# Neovim 0.13 の標準 SSH 開発

SSH接続、Neovimの配置、設定コピー、Unix socketの転送、再接続はNeovim標準の
`:connect ssh://…`を使う。RemoteDev、remote.nvim、remote-sshfs.nvimと独自workerは廃止した。
LSP・整形・検索はSSH先で実行する。SSH先にNixは必要ない。

## 手元の更新

`flake.lock`でNeovim 0.13開発版を固定する。現在の固定ソースは
`6184b150f409f317f363e215a90343ecd61585c5`。通常のHome Manager / nix-darwin適用で更新する。
当該inputだけ更新する場合は`nix flake update neovim-nightly-overlay`を使い、
評価・プロファイルビルド・設定テストを通してから適用する。

WSLではシェルとGitがNixのOpenSSHを使い、nvimラッパも子プロセスのPATHで同じOpenSSHを優先する。
Windows agentの共有にはNix管理の`wsl2-ssh-agent`を使い、Home Managerのuser serviceで起動する。
Unix SSHの`IdentityAgent`が共有socketを参照するため、既存の`SSH_AUTH_SOCK`を変更しない。
秘密鍵をコピーせず、Windows agentの鍵で認証する。
標準SSH接続はWindowsネイティブのOpenSSHには対応しない。

共通の接続先は `mise/dotfiles/.ssh/config.shared` に置き、mise の `unix` 環境が
`~/.ssh/config.shared` にリンクする。Home Manager は macOS と WSL の
`~/.ssh/config` に `Include ~/.ssh/config.shared` を設定する。macOS では
既存の設定を優先し、WSL では先に `config.local` を読み込む。共通設定の編集は
次回の SSH 実行時に反映される。Neovim のホスト補完に出ない共通ホストも、
`:connect ssh://dev` のように直接指定できる。WSL のホスト鍵は `~/.ssh/known_hosts` で管理する。

旧設定から切り替える前に、引き続き使うローカルホスト（`infra` など）の定義を
`~/.ssh/config.local` に移す。利用を終えた `ubuntu` のブロックは必要に応じて
同ファイルから外す。`dev` は共通設定にあり、接続後も agent を利用できる。

Windowsからだけ到達できるホストには、`config.local`で標準のProxyCommandを使える。
以下はWindows SSHで対象へ接続し、そのホスト自身のSSHポートへ転送する例。
Windows側の同名ホストではこのUnix専用ProxyCommandを設定しない。

```sshconfig
Host example-host
  ProxyCommand /mnt/c/Windows/System32/OpenSSH/ssh.exe -o BatchMode=yes -o StrictHostKeyChecking=yes -W localhost:22 %n
  IdentityFile none
```

Unix側の多重化・Unix socket転送はUnix OpenSSHが担当する。
接続前にUnix版sshで`ssh -G <host>`と`ssh -o BatchMode=yes <host> true`を確認する。
共有agentは`systemctl --user status wsl2-ssh-agent.service`で診断する。

## 接続・再接続

```vim
:connect ssh://myserver
:connect ssh://user@myserver:2222
```

`<leader>mc`は`:connect ssh://`を入力したコマンドラインを開く。
`<leader>mr`または引数なしの`:connect`は既知のサーバー・SSHホストを選ぶ。
新しいSSHセッションでは、接続先のフォルダ一覧が開く。フォルダ名で下位へ、
`../（親フォルダ）`で上位へ移動し、`このフォルダを使う`で決定する。
決定した場所が作業ディレクトリになり、その場所のExplorerを開く。
検索・ターミナル・LSPもそのSSH先で動く。Escでキャンセルした場合は作業場所を変えない。
後から選び直すには`<leader>mp`を使う。手動の`:cd /path/to/project`も利用できる。
既に起動しているサーバーへの再接続では選択画面を出さず、現在の作業場所を保つ。

通信断の後は手元から`:connect ssh://myserver`で再接続し、SSH先で引数なしの
`:connect`を使って元のセッションを選ぶ。編集操作があったサーバーは通信断後も保持される。
`:qall`はリモートのNeovimを終了する。旧RemoteDevDisconnectによる手元UIへの往復は使わない。
標準の`:connect`は接続元のNeovimを終了できる状態か確認してから切り替えるため、
未保存変更がある場合は保存などの処理が必要になる。

## SSH先の前提

- POSIX sh、tar、書き込み可能な`/tmp`とHOME。
- 手元からUnix版OpenSSH 7.6以降で鍵認証でき、Unix socket forwardingが許可されている。
  標準機能は`BatchMode=yes`を使うため、パスワード・対話認証は行わない。
- Neovimの自動配置はLinux glibc / macOS、x86_64 / ARM64が対象。
  自動配置にはcurlとsha256sumが必要。それ以外は対応するnvimをSSHのPATHに用意する。
- プラグイン導入にはGitとGitHubへの接続が必要。
- LSP等を管理するmiseはSSH先で別途用意する。手元のNixパスは転送しない。

手元の`stdpath('config')`は`~/.config/nvim-remote/`へコピーされる。
プラグイン本体、状態、履歴は転送されず、`NVIM_APPNAME=nvim-remote`のデータ領域を使う。
初回導入後に`:Lazy restore`で`lazy-lock.json`の固定版へ揃える。
更新時は新しく接続して設定をコピーし、`:Lazy restore`後に再起動する。

Neovim本体の自動配置は、ユーザーが選択した標準SSH機能による管理の例外とする。
LSP・整形・検索のツールはmiseで管理し、独自の成果物URL・転送・展開コードは持たない。

## SSH先のLSP・整形ツール

コピーされた`~/.config/nvim-remote/tools/mise.toml`はSSH先専用の固定バージョン定義。
手元のNix環境には適用しない。SSH先で既存のグローバル設定を上書きせず、
miseの標準conf.dとして参照する。`nvim.toml`が既にある場合は内容を確認してから配置する。

```sh
mkdir -p ~/.config/mise/conf.d
ln -s ~/.config/nvim-remote/tools/mise.toml ~/.config/mise/conf.d/nvim.toml
mise -C ~/.config/nvim-remote/tools trust
mise -C ~/.config/nvim-remote/tools install --dry-run
mise -C ~/.config/nvim-remote/tools install
```

通常の`ssh + nvim`で使う場合は、上記の`nvim-remote`を実際の設定ディレクトリに置き換える。
標準SSHは非ログインシェルのPATHを使う。mise本体をそのPATHで解決できるようにする。
設定はmise shimsをPATH末尾へ補い、プロジェクトを解析するLSPは`mise x -C <root>`を通す。
プロジェクトのmise設定はそのSSH先でtrust・installする。起動時の自動導入はしない。

Node系LSPはmiseのpath requestで実行用Nodeを固定するため、プロジェクトの
古いNodeへ引きずられない。node_modules/.binのシェルラッパーもそのまま実行する。Prettierはプロジェクト内の実体を優先し、実行用Nodeを分離する。
TypeScriptはプロジェクト版を優先し、なければmiseで導入したtsserver.jsを使う。
Go製ツールの導入はmiseのgo backendを使うため、導入用Goも定義に含める。

次はプロジェクト・接続先側で用意する。

- Pythonとvenv、Go toolchain、Rustのcargo / rustc / rustfmt / clippy。
- Ruby / Bundlerとプロジェクトのruby-lsp / rubocop / haml_lint。
- Nodeとnode_modules、ESLint本体・plugins。
- C/C++のclangd / clang-format、コンパイラ、headers、compile_commands.json。
  C/C++ツールの公式成果物はCPUごとの対応が異なるため、一律の自動配布は行わない。
- Git。追加Treesitter parserをビルドする場合はcc。

不足は`:checkhealth vim.lsp`、`:LspLog`、`:ConformInfo`で確認する。
コンパイラがない場合は追加parserを導入せず、同梱parserと通常syntaxを使う。
blinkはネイティブライブラリがあれば使い、なくてもLua実装で補完できる。
SSH先のクリップボードへのコピーにはOSC52を使い、貼り付けは端末側の操作を使う。

## 旧環境と検証

旧`~/.remote-nvim/`内のセッション・未保存バッファは標準機能へ自動移行しない。
稼働中の旧セッションで保存してから切り替える。旧ディレクトリは自動削除しない。

```sh
nix flake check --no-build
nix build --no-link '.#darwinConfigurations."uvu1-mac".config.home-manager.users.uvu1.home.path'
NVIM_TEST_BIN=/path/to/nvim-0.13 python3 -B scripts/test_nvim_config.py
mise -C mise -E unix dotfiles status
```

設定テストは実SSH先に接続せず、通常SSH / 標準SSHの環境判定、コンパイラ不足、
補完のLuaフォールバック、プロジェクトmiseと固定Nodeの併用、設定全体の起動を確認する。
実ホストの鍵認証、踏み台、通信断からの再接続は別途検証する。

## 一次情報

- [固定したNeovimの標準SSH](https://github.com/neovim/neovim/blob/6184b150f409f317f363e215a90343ecd61585c5/runtime/doc/gui.txt)
- [Neovim nightlyのNixパッケージ](https://github.com/nix-community/neovim-nightly-overlay)
- [Lazyのlockfile復元](https://lazy.folke.io/usage/lockfile)
- [mise 2026.10.17のconf.d](https://github.com/jdx/mise/blob/v2026.10.17/docs/configuration.md#conf-d)
- [wsl2-ssh-agent 0.9.7](https://github.com/mame/wsl2-ssh-agent/tree/v0.9.7)
