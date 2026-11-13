# Neovim Remote development

手元の Neovim の UI を SSH 先の Neovim に接続する。編集、LSP、整形、検索、
ターミナルは SSH 先で実行し、接続を戻してもサーバーと未保存バッファを保持する。
配置は SSH 先の `~/.remote-nvim/` 内で完結し、sudo やシェル設定の書き換えは行わない。

## 初回の準備

- 手元: このリポジトリの Home Manager / unix dotfiles を通常の手順で適用する。
  Neovim **0.12.4**、Python 3.12 以降、npm、Go 1.26 以降、Git、tar が必要。
  `remote.nvim` は Lazy が固定コミットを導入する。未導入なら `:Lazy install remote.nvim`。
- SSH: Unix 版 OpenSSH から接続できるように `~/.ssh/config`、鍵、agent を用意する。
  WSL の既存の `ssh` ラッパーは Windows 版を使うが、本機能は Home Manager が
  指定する Unix 版を使う。Windows 側の SSH 設定や agent は自動では引き継がない。
- SSH 先: Linux glibc または macOS、x86_64 / ARM64。POSIX sh、tar、gzip、
  `sha256sum` または `shasum`、通常の Unix ユーティリティ、書き込み可能な HOME が必要。
  Git 操作には Git も用意する。Windows SSH、musl、その他の CPU は対象外。
- 手元には GitHub / npm / Go module proxy / nodejs.org への接続が必要。
  SSH 先も GitHub から Neovim と一部ツールを取得する。`curl` / `wget` がない場合は
  remote.nvim が手元から転送する。SSH の Unix socket forwarding
  (`AllowStreamLocalForwarding`) を許可しておく。

`:RemoteDevHealth` で SSH 実体と依存コマンドを確認する。Home Manager 適用前に
動作を試す場合、`NVIM_REMOTE_SSH_BIN` に **Unix 版 ssh 実体の絶対パス**を指定できる。
通常は Home Manager が環境変数と `~/.config/nvim-remote/ssh-path` を用意する。

## 接続と再接続

| コマンド | キー | 動作 |
| --- | --- | --- |
| `:RemoteDevPlan` | `<leader>mp` | 固定バージョン、URL、SHA256 の表示。通信も配置もしない |
| `:RemoteDevConnect [host]` | `<leader>mc` | 接続先と作業場所を選び、準備・配置確認・接続 |
| `:RemoteDevDisconnect` | `<leader>md` | 手元の UI に戻る。SSH 先のプロセスは保持 |
| `:RemoteDevReconnect` | `<leader>mr` | 前回のプロジェクトの稼働中セッションへ再接続 |
| `:RemoteDevHealth` | `<leader>mh` | 現在の環境のツールと診断方法を表示 |

作業場所は SSH 先に存在する絶対パスまたは `~/project` で指定する。
接続先一覧には Unix 側の `~/.ssh/config` を使う。一覧にない場合は
`:RemoteDevConnect user@host` で直接指定できる。ポート、踏み台などは SSH config で指定する。
パスワードやホスト鍵の確認が必要な場合は Neovim 内の端末で認証する。

接続操作はまず SSH 先の OS / CPU / HOME / 作業場所を読み取り、手元で配布物を準備する。
初回はダウンロードと Go ツールのクロスビルドに時間がかかる。
準備後に表示する配置内容を確認して「配置して接続」を選ぶと、SSH 先へ書き込む。
キャンセルした場合、手元のキャッシュだけが残る。

接続後は `<leader>ff` / `<leader>fg` も SSH 先で検索する。`:terminal` は SSH 先で開く。
サーバーを終了する場合は SSH 先の UI で `:qa` を実行する。
通信断の後は手元の Neovim から `:RemoteDevReconnect` を実行する。
UI が残っているセッションへ別の UI を重ねて接続する操作は拒否する。
前回の接続情報は手元のキャッシュに保持するため、手元の Neovim を再起動しても再接続できる。
RPC は手元・SSH 先とも 0700 のディレクトリ内の Unix socket で待ち受け、SSH で転送する。
socket パスは 103 bytes 以下に収まる HOME / キャッシュ配置が必要で、`:` / `%` を含むパスは使えない。

## 配布するもの

| 種類 | 内容 |
| --- | --- |
| 本体・設定 | 手元と同じ版の Neovim、管理対象の設定、lazy-lock.json に固定したプラグインのソース |
| LSP | basedpyright、TypeScript、Tailwind CSS、HTML / CSS / JSON / ESLint、YAML、LuaLS、clangd、gopls、rust-analyzer |
| 整形・検索 | Prettier、Biome、Ruff、StyLua、goimports、gofumpt、rg、fd |
| 補助 | LSP 専用の Node バイナリ、tree-sitter CLI。Linux の LLVM 成果物にあれば clang-format も配置 |

Node 系ツールは専用 Node を直接呼ぶラッパーで動かし、プロジェクトの Node と分離する。
Go 製ツールは手元で `CGO_ENABLED=0` によりクロスビルドし、SSH 先には実行ファイルだけを送る。
SSH 先に Nix、mise、npm、Go コンパイラは必要ない。
Neovim の runtime や LuaLS のデータはディレクトリを伴うため、配布単位は専用ディレクトリになる。

次のものは **プロジェクト側で用意する**。

- Go 開発: Go toolchain。Rust 開発: cargo / rustc / rustfmt / clippy とプロジェクトの依存関係。
- Python 開発: Python と必要な仮想環境。仮想環境のパスは pyright のプロジェクト設定で指定する。
- Ruby 開発: Ruby / Bundler と `Gemfile` の ruby-lsp / rubocop / haml_lint など。
  ロック済みの gem は `bundle exec` で呼ぶ。
- Web 開発: 実行・ビルド用の Node とプロジェクトの node_modules、ESLint 本体 / plugins など。
- C/C++ 開発: toolchain / headers / compile_commands.json。macOS の整形は利用可能な
  clang-format、または clangd の LSP formatting にフォールバックする。

LSP は SSH の非対話シェルから継承した PATH を使う。ログインシェルの設定読み込みや
プロジェクトごとのランタイム切り替えは行わない。必要な処理系をその PATH で解決できるようにする。
不足時は `:RemoteDevHealth`、`:checkhealth vim.lsp`、`:LspLog`、`:ConformInfo` で確認する。
配布対象外の linter が存在しなければ、その linter はスキップする。

補完は blink の Lua 実装を使う。AI、DAP、テスト連携は SSH 先では無効にする。
Treesitter の追加 parser は SSH 先に `cc` と tree-sitter CLI が揃う場合のみビルドする。
compiler がない環境では Neovim 同梱 parser と通常の syntax を使う。
クリップボードへのコピーは OSC52 を使い、外部アプリからの貼り付けは端末の貼り付け操作を使う。
`p` は直近の Neovim 内の yank を利用する。OSC52 を許可した端末が必要。

## 配置と更新

```text
~/.remote-nvim/
  releases/<構成のハッシュ>/
    nvim/<version>/         # Neovim 本体・runtime
    config/nvim/           # 管理対象の設定
    data/nvim/lazy/        # 固定したプラグインソース
    data/nvim/portable/    # 専用 Node・LSP・ツール
    bin/                   # remote.nvim が取得する単体ツール
    dev-nvim               # remote profile 用起動コマンド
  current -> releases/<構成のハッシュ>
  sessions/<projectのハッシュ>.json
  run/
```

公式成果物の SHA256 と npm / Go のロックを検証する。プラグインは固定コミットから
取得し、手元のインストール済みディレクトリやそのビルド結果はコピーしない。
転送後にもファイルの SHA256 を検証してから Neovim を実行し、設定の起動に成功した
release へ `current` を atomic rename で切り替える。失敗しても以前の release と
稼働中セッションは保持する。設定に含まれる手元専用の秘密情報は置かないこと。
キャッシュ、履歴、認証状態、`.git`、ネイティブビルド結果は配布対象に含めない。

設定やロックを変更したら `:RemoteDevConnect` で新しい release を準備する。
既存のプロジェクトのサーバーが動いている場合は、未保存作業を守るためそのサーバーへ戻る。
新しい release で起動し直す場合は、作業を保存して SSH 先で `:qa` した後に接続する。
`:RemoteDevReconnect` は配置を更新せず、前回の release を使う。
古い release や手元キャッシュの自動削除は行わない。

手元の配布キャッシュは `stdpath('cache')/remote-dev/` に置く。
Linux ARM64 向け clangd は LLVM のフルアーカイブから必要部分を取り出すため、
手元にはダウンロード・展開用の十分なディスク容量が必要。
異なる手元インスタンスからの同時配置は避ける。

更新対象は次のファイルにまとめている。

- `mise/dotfiles/.config/nvim/remote-dev/artifacts.json`: 公式 URL と SHA256。
  Neovim 更新時は手元の版と 4 platform の成果物を同時に更新する。
  `remote.nvim` 更新時は plugin spec、lazy-lock.json、manifest のコミットも揃える。
- 同ディレクトリの `package.json` / `package-lock.json`: 専用 Node で動かすツール。
  手元の Nix 管理 npm で `npm install --package-lock-only --ignore-scripts --no-audit --no-fund`。
- 同ディレクトリの `go.mod` / `go.sum`: Go ツールと依存関係。
  手元の Nix 管理 Go で更新し、`go mod tidy` と 4 target のクロスビルドを確認する。
- `mise/dotfiles/.config/nvim/lazy-lock.json`: プラグインの固定コミット。

## 検証と一次情報

`python3 -B scripts/test_nvim_remote_dev.py` は実ホストに接続せず、配置の検証・失敗時の保持・
UI の往復と未保存バッファの保持を確認する。
実装時には Linux x86_64 の公式成果物で remote.nvim の配布、設定全体の起動、LSP と整形を検証した。
ローカルの実 OpenSSH サーバーでも Unix socket の転送、コマンドによる UI の往復、
未保存バッファの保持、転送解除を確認した。Go ツールは 4 target のクロスビルドを検証した。
macOS / ARM64 での実機起動と実ホストへの SSH 接続は別途必要。

- [remote.nvim v0.2.1](https://github.com/advaypakhale/remote.nvim/tree/v0.2.1)
- [Neovim 0.12.4 remote UI / connect / detach](https://github.com/neovim/neovim/blob/v0.12.4/runtime/doc/remote.txt)
- [Neovim 公式成果物](https://github.com/neovim/neovim/releases/tag/v0.12.4)
- [Node 24.22.2 SHASUMS](https://nodejs.org/dist/v24.22.2/SHASUMS256.txt)
- その他の成果物は `:RemoteDevPlan` に表示する各 upstream の公式 GitHub Releases を参照。
