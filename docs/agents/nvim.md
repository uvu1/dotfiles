# Neovim の運用・変更時の注意

Neovim は 0.13 以降専用。手元は `flake.lock`、プラグインは `lazy-lock.json` で固定する。
旧版向け API フォールバックや、廃止済みプラグインの分岐を復活させない。

## 責務

- `config/`: 起動、基本オプション、自動保存、手元と SSH 先の環境差。
- `plugins/`: 各プラグインの設定と公開 API による接続。既定値は操作方針として意図がある場合だけ明示する。
- `lib/buffer.lua`: 自動保存・整形・lint が対象にする通常ファイルの判定。
- `lib/project.lua`: formatter / lint の採用設定や bundle の探索。診断集計のプロジェクト範囲とは別の責務。
- `lib/mise.lua`: プロジェクト処理系で LSP / lint / DAP を実行するための argv と環境。単なる汎用 wrapper に統合しない。
- `lib/python.lua`: 有効化済み venv → プロジェクトの `.venv` / `venv` → mise の順で Python を解決。DAP / Neotest / 版表示が共有する。
- `statusline/`: ウィンドウの対象、プロジェクト内診断集計、OS・実行環境などの情報取得。描画・時計・バッファの幅計算は lualine に任せる。

## 維持する操作と表示

- DAP・Neotest・Overseer は維持する。DAP が使う Overseer の `preLaunchTask` / `postDebugTask` とコメント付き `launch.json` の読込も維持する。
- just は Overseer 内蔵テンプレートへ任せ、`module = "^just$"` の hook で quickfix 出力だけを追加する。独自テンプレートを二重登録しない。
- AtCoder の `<leader>c*` は標準端末で `mise run` を直接実行する。Overseer / ToggleTerm へ置き換えない。
- Flash の `s/S/r/R` と `f/F/t/T/;/,` の拡張を維持する。文字移動は同一バッファ内で行をまたぐ。`f/F/t/T` を標準へ戻す変更は別途判断する。
- コード構造は Snacks の `<leader>ss/sS/sf` と treesitter-context。`]m/[m/]]/[[` は標準 ftplugin に任せ、言語横断の独自上書きをしない。
- 折り畳みは標準 `zR/zM`、パーサが利用可能なら Treesitter foldexpr、なければ indent。UFO の `zp` プレビューは提供しない。
- 診断は標準の行末 `virtual_text`。詳細は `<C-w>d` や診断 picker。Noice の入力ポップアップは維持する。
- 自動保存は `BufLeave` / `FocusLost`。失敗は通知して未保存の内容を保持する。保存前の整形・保存後と読込後の lint を維持する。

下段には、モード、プロジェクト内の読込済みバッファの診断合計、OS、言語と実行環境の版、
行・バイト列、インデント、文字コード、改行形式、時刻をウィンドウごとに表示する。
Explorer は件数、上段はファイルパス、tabline は組込のバッファ一覧。Aerial のパンくずは使わない。
空の filetype は `text`、空の fileencoding は全体の encoding、版が不明なら版部分を省略する。

版表示はファイルの近傍のプロジェクト設定を起点に非同期解決し、ディレクトリ・言語ごとに
5 分キャッシュする。Python は有効な venv も区別する。設定ファイルを保存したらキャッシュを
無効化し、無効化前の非同期結果は採用しない。再描画は lualine の更新キューへ渡し、
独自の常時タイマーや重複する強制更新 autocmd を追加しない。

## ツール解決の注意

LSP・formatter・linter の実体とフォールバック処理系は Nix、プロジェクトの版指定は mise。
SSH 先の供給と接続手順は [標準 SSH 開発](../nvim-remote-dev.md) を参照する。

`lib/mise.lua` は、mise activation 前の `__MISE_ORIG_PATH` を土台として渡す。
継承した PATH をそのまま別プロジェクトの `mise x -C` へ渡すと、起動元の処理系が混ざる。
また、`uv.spawn` の環境は置換なので HOME・GEM_* 等を保持する必要がある。
未導入の処理系を自動インストールしたり、宣言を無視してグローバル版へ落としたりしない。

Node 製サーバーは解析対象の Node と分離する。SSH 先ではエディタ用 Node を固定する。
Prettier / Biome はプロジェクト設定と `node_modules/.bin` を優先する既存の選択を維持する。
全コマンドを一律に mise で包まない。Go / Rust のテスト、Jest / Vitest、Python venv は
アダプタごとに解決方法が違う。

Ruby の bundle に `ruby-lsp` がある場合は `bundle exec` を使う。Nix の Ruby LSP が
別の Ruby に固定されて起動に失敗するプロジェクトでは、プロジェクト固有の `mise.local.toml`
で `gem:ruby-lsp` の採用版を固定し、その Ruby で導入する。ローカル専用設定は Git 管理外にする。
`haml_lint` は bundle にあるプロジェクトだけで実行し、Ruby の診断・整形をグローバル
Rubocop と二重化しない。

## 検証と調査

```sh
python3 scripts/test_nvim_config.py
stylua --check mise/dotfiles/.config/nvim
mise -C mise -E unix dotfiles status
```

テストは隔離した HOME とローカルの固定済みプラグインを使う。SSH 接続、パッケージ導入、
競プロの実テスト・提出、実際の Claude との通信はしない。Claude サーバーの起動・停止と
lockfile の書込みも隔離環境内に限定する。

LSP が起動しない場合は、`command -v <server>`、`mise x -C <project> -- <server> --version`、
`:LspLog`、`:checkhealth vim.lsp` の順で確認する。整形は `:ConformInfo`、lint は採用設定と
bundle の有無を確認する。プロジェクト設定の trust や不足処理系の導入はユーザーが明示的に行う。
