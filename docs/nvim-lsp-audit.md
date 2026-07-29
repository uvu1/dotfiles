# Neovim LSP / formatter / linter 供給と設定の評価

## Summary

- 対象は `mise/dotfiles/.config/nvim` の LSP 層と、それを支える formatter / linter の供給元。補完層（blink.cmp）は `docs/nvim-completion-audit.md` の管轄なので重複させない。
- **LSP サーバ 12 本すべてを mason.nvim が供給している**。`AGENTS.md` の「ユーザーツールは `mise/` に置く」方針に対する未文書の第 3 供給層で、`dotflow update` の更新経路にも入っていない。実測の結果、**12 本すべて＋`clang-format` が mise でも供給可能**と確認できた。
- 最大の実害は **yamlls の `yaml` テーブルが `settings` の外に置かれていたこと**。`vim.lsp.config` は未知のトップレベルキーを無検査で受理するため、エラーも警告も出ないまま schemastore.nvim の 1310 スキーマが 1 つも送信されていなかった。しかも既定の `schemaStore.enable` は「有効＋ネットワーク URL」なので、オフラインで固定する意図の設定が黙ってネットワーク取得に化けていた。
- 次に **copilot の telemetry が `all` のままだった**。`vim.lsp.config("copilot", {})` が空呼び出しで no-op だったため、lspconfig 既定が素通ししていた。同じファイルで Red Hat の telemetry だけは（既定と重複して）無効化していた。
- **有効サーバ集合がリポジトリで宣言されていなかった**。`vim.lsp.enable` は 1 箇所も無く、`automatic_enable = true` が mason のインストール済み全件を有効化する。`ensure_installed` に無い `clangd` が動いていたのがその証拠。
- 加えて **tailwindcss が全 git リポジトリの markdown に attach**、**`clang_format` が非推奨エイリアスかつバイナリ不在で無警告 LSP フォールバック**、**lua_ls の `workspace.library` が起動順依存**。

以降、ファイルパスは断りが無い限り `mise/dotfiles/.config/nvim/` からの相対パス。

## Progress

| 項目 | 区分 | 状態 |
| --- | --- | --- |
| Finding 1: yamlls の `yaml` が `settings` 外で 1310 スキーマ未送信 | 修正（重大） | 対応済み |
| Finding 2: 有効サーバ集合が未宣言 | 修正（重大） | 対応済み |
| Finding 3: mason が未文書の第 3 供給層、`biome` 二重供給 | 要判断（重大） | **対応済み（mason 撤去・mise へ移行）** |
| Finding 4: nvim-lint の `biomejs` が無条件かつディスク内容を lint | 修正 | 対応済み |
| Finding 5: tailwindcss / cssls の過剰 attach と多重診断 | 修正 | 対応済み |
| Finding 6: `clang_format` が非推奨エイリアス＋バイナリ不在 | 修正 | 対応済み |
| Finding 7: lua_ls の `workspace.library` が起動順依存 | 修正 | 対応済み |
| Finding 8: Windows で LSP / formatter が成立しない | 要判断 | 未対応（**Finding 3 の対応で悪化**） |
| Finding 9: リポジトリ自身の言語が未カバー、formatter 設定も未追跡 | 要判断 | 未対応 |
| Finding 10: copilot telemetry `all` ほか無効・冗長な設定 | 整理 | 対応済み |

## Verified Facts

推測ではなく実測した内容。`$VIMRUNTIME` は `~/.local/share/mise/installs/neovim/0.12.4/share/nvim/runtime`。

### 供給元

| 検証項目 | 方法 | 結果 |
| --- | --- | --- |
| Neovim バージョン | `nvim --version` | **0.12.4**（`mise/dotfiles/mise/config.unix.toml:15` で固定） |
| `automatic_enable` の対象 | `mason-lspconfig/features/automatic_enable.lua:56` | `registry.get_installed_package_names()` の**全件**を `vim.lsp.enable` する。**`ensure_installed` は参照されない** |
| 修正前の有効サーバ | headless で `vim.lsp._enabled_configs` を印字 | 12 個。`ensure_installed` の 11 個に無い **`clangd` を含む** |
| mason の実インストール | `~/.local/share/nvim/mason/packages` | 12 パッケージ。各 `mason-receipt.json` の `.source.id` は npm 9 / GitHub 3 |
| mason の版 | 同上 | biome 2.5.3 / clangd 22.1.6 / copilot-language-server 1.520.0 / lua-language-server 3.18.2 / pyright 1.1.411 / rust-analyzer 2026-07-06 / tailwindcss-language-server 0.14.29 / typescript-language-server 5.3.0 / vscode-langservers-extracted 4.10.0 / yaml-language-server 1.24.0。**リポジトリのどこにも記録が無い** |
| mason の PATH 操作 | `mason/settings.lua:17`, `mason/init.lua:25` | `PATH = "prepend"` が既定。`lua/plugins/lsp.lua:4` は `opts = {}` なので既定のまま |
| mason.nvim のロード契機 | headless で `lazy.core.config.plugins` | `lazy = true`。mason-lspconfig（`VeryLazy` / `BufReadPre`）の依存としてのみロードされる |
| バイナリ解決の切り替わり | mason の bin を除いた PATH で、`require("lazy").load({plugins={"mason.nvim"}})` の前後に `exepath()` を比較 | **`biome` のみ mise → mason に入れ替わる**。LSP 12 本はロード後にのみ解決。`prettier` / `ruff` / `stylua` / `yamllint` / `rustfmt` は不変 |
| `biome` の版の乖離 | 両バイナリに `--version` | mason **2.5.3** / mise **2.5.4** |
| rust ツールチェーンの実体 | `~/.local/share/mise/installs/rust/1.97.0` | `~/.cargo/bin` への symlink（mise の `core:rust` は rustup へ委譲）。`rustfmt` / `cargo-clippy` はここ由来。**rustup 自体は nix にも mise にも宣言が無い** |
| rustup の rust-analyzer | `~/.cargo/bin/rust-analyzer --version` | 「unavailable for the active toolchain」→ **mason のバイナリへフォールバックする** |
| nix の在庫 | `nix/home.nix:18-31` | curl / git / mise / sheldon / zsh / podman / docker-compose ＋ Linux 限定の gcc など。**言語サーバ・formatter・linter は 0 件** |
| Windows の toolset | `mise/dotfiles/mise/config.windows.toml` | 14 tools。formatter は `stylua` のみ。**node / python / rust が無い**。`:18` は `neovim = "latest"`（unix は 0.12.4 固定） |
| mason への言及箇所 | リポジトリ全文検索 | `lua/plugins/lsp.lua` の 3 行のみ。`AGENTS.md` と `README.md`（342 行）に記述なし |
| 更新経路 | `.dotflow.toml`, `scripts/` | mise と home-manager と `sync-ai-config.sh` のみ。**nvim プラグイン / mason パッケージの更新ステップは無い** |

### サーバごとの設定

| 検証項目 | 方法 | 結果 |
| --- | --- | --- |
| `vim.lsp.config` のマージ規則 | `$VIMRUNTIME/lua/vim/lsp.lua:381-387` | `vim.tbl_deep_extend('force', self._configs[name] or {}, cfg)` |
| 設定の優先順 | 同 `:341-362` | `'*'` → rtp の `lsp/*.lua` → ユーザ設定。**blink の `'*'` capabilities は最下位** |
| 未知トップレベルキーの扱い | 同 `:475-479` `validate_config` | `cmd` / `reuse_client` / `filetypes` のみ検証。**他は無検査で保持され、サーバへは送られない** |
| 修正前の yamlls 解決結果 | headless で `vim.lsp.config["yamlls"]` | トップレベルに `yaml`（`schemas` 1310 件）が居座り、`settings.yaml` は lspconfig 既定の `format.enable` のみ |
| 修正後の yamlls 実設定 | headless で attach 後に `client.settings.yaml` | `schemas=1310` / `schemaStore.enable=false` / `keyOrdering=false` / `format.enable=true` / `kubernetes` あり。トップレベル `yaml` は消滅 |
| lspconfig の yamlls 既定 | `nvim-lspconfig/lsp/yamlls.lua` | `settings.redhat.telemetry.enabled = false` と `settings.yaml.format.enable = true` を**既に持つ**。`on_init` で `documentFormattingProvider = true` を立てる |
| 修正前の copilot 解決結果 | headless で `vim.lsp.config["copilot"]` | `settings.telemetry.telemetryLevel = "all"`（lspconfig 既定） |
| 修正後の copilot | headless で attach 後に `client.settings` | `telemetryLevel = "off"` |
| 修正前の lua_ls library | headless で `#library` と `#nvim_get_runtime_file("",true)` | `config()` 時点 **12 件** / 後の rtp **24 件**。プラグインは 35 個（`lazy-lock.json`） |
| 修正後の lua_ls library | 同上 | 固定 3 件（`$VIMRUNTIME/lua`、`~/.config/nvim/lua`、`${3rd}/luv/library`）。ロード順に依存しない |
| eager ロードされるプラグイン | `rg 'lazy = false\|priority'` | `nvim-lspconfig` / `nvim-treesitter` / colorscheme / `snacks.nvim` の 4 つのみ |
| 修正前の markdown への attach | `nvim --headless README.md` ＋ `get_clients` | `copilot` と **`tailwindcss`**（ともに root = リポジトリ） |
| 修正後の markdown への attach | 同上 | **`copilot` のみ** |
| tailwindcss の attach 条件 | `nvim-lspconfig/lsp/tailwindcss.lua:26-88,124-149` | `filetypes` が約 50 種（`markdown` / `mdx` / `php` / `clojure` / `haml` などを含む）、`root_files` の末尾が **`.git`**、`workspace_required = true` |
| cssls の既定 | `nvim-lspconfig/lsp/cssls.lua:35-42` | `filetypes = { css, scss, less }`、`root_markers = { package.json, .git }`、`css/scss/less.validate = true` |
| jsonls の既定 | `nvim-lspconfig/lsp/jsonls.lua:36-40` | `root_markers = { .git }`、`settings` なし、`init_options.provideFormatter = true` |
| biome の attach 条件 | `nvim-lspconfig/lsp/biome.lua:41-80` | `workspace_required = true` ＋ `root_dir` が `biome.json(c)` / `package.json` の `biomejs` 宣言を要求。**無ければ attach しない** |
| lua_ls の既定 | `nvim-lspconfig/lsp/lua_ls.lua:86-90` | `codeLens.enable = true`、`hint.enable = true`。`root_markers` に `stylua.toml` を含む |
| LSP 付随機能の呼び出し | nvim 設定の全文検索 | `vim.lsp.inlay_hint` / `codelens` / `document_color` の呼び出しは**皆無**。上記の要求は表示されない |
| `vim.diagnostic.config` の既定 | `$VIMRUNTIME/lua/vim/diagnostic.lua:393-399` | `virtual_text = false`、`virtual_lines = false` が既定 |
| 修正後の有効サーバ | headless で `vim.lsp._enabled_configs` | 12 個。`lua/plugins/lsp.lua:205-218` の明示列挙と完全一致 |

### formatter / linter

| 検証項目 | 方法 | 結果 |
| --- | --- | --- |
| `clang_format` の正体 | `conform/formatters/clang_format.lua:3` | `conf.meta.deprecated = true`。正名は同ディレクトリの `clang-format.lua` |
| formatter 不在時の挙動 | `conform/init.lua:795-797`, `:512-521` | `available = false` を `log.debug` に落とすだけで**通知せず** LSP フォーマットへ移る |
| 修正前の `clang-format` | mason ロード後の `exepath` / `command -v` | **`(none)`**。mason の clangd パッケージは `clangd` のみを link |
| 修正後の `clang-format` | `mise install` 後に `:ConformInfo` 相当を headless で取得 | `clang-format available=true`（22.1.8、mise の shim 経由） |
| nvim-lint biomejs の入力 | `nvim-lint/lua/lint/linters/biomejs.lua:36-38`, `lint.lua:383` | `stdin = false` ＋ ファイル名付与 → **ディスク上の内容を lint する** |
| 修正前の biome 適用条件 | 3 者のソース読解 | LSP は biome 設定必須、conform は `biome.json(c)` のみ判定、nvim-lint は**無条件** |
| 修正後の biome ゲート | 一時 git リポジトリ 3 種（設定なし / `biome.json` / `package.json` に `@biomejs/biome`）で判定を印字 | 設定なし → `run={}`、`biome.json` → `run={biomejs}`、`package.json` 宣言 → `run={biomejs}` |
| 追跡されている formatter 設定 | `git ls-files` | `stylua.toml` 2 件のみ（nvim / wezterm）。prettier・biome・yamllint・ruff・clang-format・editorconfig は**未追跡** |
| yamllint の既定ルール | `yamllint/conf/default.yaml` | `document-start: warning`（`---` を要求するが prettier は付けない）、`truthy: warning`（Actions の `on:` に反応）、`line-length` 80 |
| リポジトリの言語構成 | `git ls-files` の拡張子集計 | 全 106 件。lua 49 / toml 12 / md 9 / ps1 8 / zsh 5 / sh 4 / nix 3 / json 3 |

### mise への移行可能性（Finding 3 用）

`mise ls-remote` で実測。**全 12 本＋`clang-format` が mise で供給可能**。

| サーバ | mise backend | 取得できた版 | mason の版 |
| --- | --- | --- | --- |
| lua-language-server | `aqua:LuaLS/lua-language-server`（registry 済） | 3.18.2 | 3.18.2 |
| rust-analyzer | `aqua:rust-lang/rust-analyzer`（registry 済） | 2026-07-27 | 2026-07-06 |
| biome | registry 済（既に導入済み） | 2.5.5 | 2.5.3 |
| typescript-language-server | `npm:typescript-language-server` | 5.3.0 | 5.3.0 |
| yaml-language-server | `npm:yaml-language-server` | 1.24.0 | 1.24.0 |
| jsonls / html / cssls | `npm:vscode-langservers-extracted` | 4.10.0 | 4.10.0 |
| pyright | `npm:pyright` | 1.1.411 | 1.1.411 |
| tailwindcss-language-server | `npm:@tailwindcss/language-server` | 0.16.0 | 0.14.29 |
| copilot-language-server | `npm:@github/copilot-language-server` | 1.526.0 | 1.520.0 |
| clangd | `ubi:clangd/clangd` | 22.1.6 | 22.1.6 |
| clang-format | registry 済（今回導入） | 22.1.8 | （不在） |

Finding 9 に関わる補完として `taplo` 0.10.0 / `shellcheck` 0.11.0 / `shfmt` 3.13.1 も mise で供給可能。nix formatter（`nixpkgs-fmt` / `alejandra`）は mise registry に無く、既にベース層である nix 側が適切。

## 構成の全体像

### 供給層

| 層 | 宣言箇所 | LSP サーバ | formatter / linter | 版の固定 | 更新経路 |
| --- | --- | --- | --- | --- | --- |
| Nix + home-manager | `nix/home.nix:18-31` | 0 件 | 0 件 | flake.lock | `dotflow update` |
| mise（unix） | `mise/dotfiles/mise/config.unix.toml` | 0 件 | stylua / prettier / yamllint / ruff / biome / clang-format | `latest` 中心 | `dotflow update` |
| mise（windows） | `mise/dotfiles/mise/config.windows.toml` | 0 件 | stylua のみ | `latest` | `dotflow update` |
| rustup（`~/.cargo/bin`） | **宣言なし**（mise の `core:rust` が委譲） | 0 件 | rustfmt / clippy | rustup toolchain | なし |
| **mason** | `lua/plugins/lsp.lua:205-223` ＋ 手動 `:Mason` | **12 本** | 0 件 | **記録なし** | **なし** |

### サーバ 12 本

| サーバ | 実体（供給元・版） | repo 内の設定 | attach 範囲 |
| --- | --- | --- | --- |
| lua_ls | mason 3.18.2 | `lsp.lua:61` runtime / globals / library / telemetry | lua |
| yamlls | mason 1.24.0 | `lsp.lua:39` schemastore 1310 件 ＋ k8s glob | yaml 系 4 種 |
| jsonls | mason 4.10.0 | `lsp.lua:52` schemastore ＋ validate（今回追加） | json / jsonc |
| cssls | mason 4.10.0 | `lsp.lua:134` validate 無効（今回追加） | css / scss / less |
| html | mason 4.10.0 | なし（lspconfig 既定） | html 系 |
| tailwindcss | mason 0.14.29 | `lsp.lua:92` filetypes 12 種 ＋ root_dir（今回追加） | 絞り込み済み |
| ts_ls | mason 5.3.0 | なし（空呼び出しを削除） | ts / js 系 |
| biome | **mason 2.5.3**（mise 2.5.4 と競合） | なし | biome 設定のある ts/js/json/css |
| pyright | mason 1.1.411 | なし | python |
| rust_analyzer | mason 2026-07-06 | `lsp.lua:142` allFeatures / clippy | rust |
| clangd | mason 22.1.6（**手動導入 → 今回宣言化**） | なし | c / cpp |
| copilot | mason 1.520.0 | `lsp.lua:157` telemetry off（今回追加） | 全 filetype |

`vim.lsp.enable` は `lua/plugins/lsp.lua:226` の 1 箇所だけになり、有効サーバ集合は `:205-218` のリストが唯一の正本になった。

### filetype × ツール

| filetype | LSP | formatter (conform) | linter (nvim-lint) | 実体の供給元 | 設定ファイル |
| --- | --- | --- | --- | --- | --- |
| ts / tsx / js / jsx | ts_ls ＋ biome | prettier または biome | biomejs（biome 設定時のみ） | mason / mise | プロジェクト依存 |
| json / jsonc | jsonls ＋ biome | prettier または biome | biomejs（同上） | mason / mise | schemastore |
| css | cssls ＋ tailwindcss ＋ biome | prettier または biome | biomejs（同上） | mason / mise | プロジェクト依存 |
| yaml | yamlls | prettier | yamllint | mason / mise | **yamllint 既定のみ** |
| rust | rust_analyzer | rustfmt | — | mason / **rustup** | — |
| python | pyright | ruff_format | ruff | mason / mise | — |
| c / cpp | clangd | clang-format | — | mason / mise | **なし（LLVM 既定）** |
| lua | lua_ls | stylua | — | mason / mise | `stylua.toml` |
| markdown（9 件） | — | — | — | — | — |
| toml（12 件） | — | — | — | — | — |
| ps1（8 件） | — | — | — | — | — |
| zsh / sh（9 件） | — | — | — | — | — |
| nix（3 件） | — | — | — | — | — |

下 5 行が Finding 9 の空白。リポジトリの追跡ファイル 106 件のうち、LSP と formatter が揃っているのは lua 49 件だけ。

## Finding 1: yamlls の `yaml` テーブルが `settings` の外にあった（最優先・対応済み）

修正前の `lua/plugins/lsp.lua`。

```lua
vim.lsp.config("yamlls", {
  settings = {
    redhat = { telemetry = { enabled = false } },
  },
  yaml = {                    -- ← settings の外
    validate = true, completion = true, hover = true,
    keyOrdering = false,
    schemaStore = { enable = false, url = "" },
    schemas = yaml_schemas,   -- schemastore.nvim ＋ kubernetes glob
  },
})
```

`$VIMRUNTIME/lua/vim/lsp.lua:475-479` の `validate_config` は `cmd` / `reuse_client` / `filetypes` しか検証しない。未知のトップレベルキーは**無検査で保持され、サーバへは送られない**。エラーも警告も出ないため気付けない。

### 影響

- **schemastore.nvim の 1310 スキーマが 1 つも届いていなかった**。`kubernetes` glob も同様。
- `schemaStore.enable = false` と `url = ""` が届かないため、yamlls 側の既定（**有効＋ `https://www.schemastore.org/api/json/catalog.json` へのネットワーク取得**）がそのまま生きていた。オフラインで固定する意図が、黙ってネットワーク依存に化けていた。
- `keyOrdering = false` も届かず、キー順の警告が出る既定のままだった。
- glob に綴り誤り `applicatinsets` があり（`lsp.lua:31`）、`.yaml` / `.yml` の対も非対称だった。設定が死んでいたので誰も気付けなかった。

### 対応方針

`yaml` を `settings` 配下へ移した。あわせて、

- lspconfig 既定と重複する `settings.redhat` ブロックを削除（`lsp/yamlls.lua` が既に同じ値を持つ）。
- 既定と同値の `validate` / `completion` / `hover` を削除。
- `applicatinsets` → `applicationsets` に修正し、`.yaml` / `.yml` の対を揃えた。**この修正で初めて glob が実効化するため、Finding 1 と同時に直す必要があった**。

修正後の実測は `schemas=1310` / `schemaStore.enable=false` / `keyOrdering=false` / `format.enable=true`（lspconfig 既定を維持、退行なし）。

## Finding 2: 有効サーバ集合がリポジトリで宣言されていなかった（対応済み）

`mason-lspconfig/features/automatic_enable.lua:56` は `registry.get_installed_package_names()`、つまり **mason にインストール済みの全パッケージ**を `vim.lsp.enable` する。`ensure_installed` は参照されない。

修正前は `vim.lsp.enable` の呼び出しがリポジトリに 1 箇所も無く、有効サーバ集合は `~/.local/share/nvim/mason` というマシンローカルな状態が決めていた。

### 影響

- `ensure_installed`（11 本）に無い **`clangd` が実際には有効化されていた**。誰かが `:Mason` で手動導入した痕跡がそのまま挙動になっていた。
- 逆に、mason のインストールに失敗したサーバは黙って無効になる。どちらもリポジトリの差分には現れない。
- 別マシンで `git clone` しても同じサーバ構成にならない。

### 対応方針

`automatic_enable = false` にし、`servers` の 1 リストを `ensure_installed` と `vim.lsp.enable` の両方に渡した（`lua/plugins/lsp.lua:205-226`）。現状の挙動を保つため `clangd` をリストに含め、マシンローカルな既成事実をリポジトリ側の宣言に昇格させた。

`vim.lsp.enable` は mason-lspconfig の `config` 内、つまり依存の mason.nvim が PATH を prepend し終えた後で呼ぶ。修正後の実測で有効サーバがリストと完全一致することを確認した。

## Finding 3: mason が未文書の第 3 供給層で、`biome` が二重供給（要判断・未対応）

`AGENTS.md:6-7` は「Nix と Home Manager は再現可能なベース環境に限定」「ユーザーツールと通常の dotfiles は `mise/` に置く」と定めている。`README.md`（342 行）にも mason の記述は無い。にもかかわらず LSP サーバ 12 本は mason 由来で、リポジトリ内の言及は `lua/plugins/lsp.lua` の 3 行だけ。

### 影響

- **版がどこにも記録されていない**。`lazy-lock.json` が固定するのはプラグインであってサーバではない。実際に入っている 12 本の版（biome 2.5.3、lua-language-server 3.18.2、rust-analyzer 2026-07-06 …）は再現できない。
- **更新経路が無い**。`.dotflow.toml` → `scripts/update-wsl.sh` → `dotflow update` は mise と home-manager と AI 設定を更新するが、nvim プラグインと mason パッケージには触らない。手動 `:Mason` / `:Lazy` に依存している。
- **`biome` が二重供給**。`config.unix.toml:32`（mise 2.5.4）と mason（2.5.3）の両方にあり、`mason/settings.lua:17` の `PATH = "prepend"` 既定によって **mason 側が勝つ**。mason.nvim は `lazy = true` なので、どちらが使われるかは事実上プラグインのロード順で決まる。conform と nvim-lint が呼ぶ `biome` と、LSP が使う `biome` が別バイナリ・別版になりうる。
- rustup も同様に宣言が無い（`~/.cargo/bin`）。mise の `rust = "1.97.0"` は `core:rust` バックエンドで rustup へ委譲しているだけで、`rustfmt` / `clippy` の実体は rustup 管理下にある。`~/.cargo/bin/rust-analyzer` は「active toolchain に無い」と言って **mason のバイナリへフォールバックする**という捻れた依存になっている。

### 対応方針

実測の結果、**12 本すべてと `clang-format` が mise で供給可能**（上の表）。選択肢は 3 つ。

1. **mise へ寄せる。** `config.unix.toml` に列挙し、mason と mason-lspconfig を外す。`AGENTS.md` の方針と `dotflow update` の更新経路に自然に乗り、版も repo で固定される。`ubi:` / `npm:` / `aqua:` バックエンドで足りる。欠点は npm 系 9 本が node 依存になること（unix には既に node がある。Windows は Finding 8）。
2. **mason を正式な第 3 層として文書化する。** `AGENTS.md` と `README.md` に「言語サーバは mason が持つ」と明記し、`dotflow` の `after_sync` に `nvim --headless "+MasonUpdate" +qa` 相当を足して更新経路に載せる。版の固定は別途必要。
3. **`biome` だけ片方に寄せる。** 最小の手当て。二重供給と版差だけを解消する。

### 実施結果（選択肢 1 を採用）

mason.nvim と mason-lspconfig.nvim を撤去し、全サーバを `config.unix.toml` に版固定で宣言した。`lazy-lock.json` は 35 → 33 エントリ。あわせて対象言語を rust / python / ruby / haml / react / c++ / go / yaml / json に拡張した。

**プロジェクト解決の実装**: `lua/lib/mise.lua` が `mise x -C <root_dir> --` で包む `cmd` 関数を生成する。nvim 自身が mise の shim 経由で起動するため nvim の PATH にはグローバルの具体パスが並び、素のコマンド名ではプロジェクトの `mise.toml` / `.tool-versions` が効かない。実測比較:

| 実行方法 | 結果（global 1.97.0、プロジェクト pin 1.85.0） |
| --- | --- |
| 素の `rustc` をプロジェクト内で実行 | 1.97.0（誤り。PATH に影にされる） |
| `mise x -C <project> -- rustc` | **1.85.0**（正しい。呼び出し元 cwd に依存しない） |

ラップ対象は「サーバがプロジェクトの処理系を実行・内省しないと正しい答えを出せないか」で判断し、`rust_analyzer` / `gopls` / `ruby_lsp` / `basedpyright` の 4 本のみ。バージョン依存の実体がリポジトリ内のファイル（`node_modules/typescript`、`compile_commands.json`、JSON schema、`.eslintrc`）なら、サーバ自身が workspace から解決するのでラップは無益で、かつプロジェクトが古い node を pin していると逆に壊れる。

end-to-end の実証（`ps` で実プロセスを確認）:

```
/home/uvu1/.local/share/mise/installs/rust-analyzer/2026-07-27/rust-analyzer
/home/uvu1/.rustup/toolchains/1.85.0-x86_64-unknown-linux-gnu/libexec/rust-analyzer-proc-macro-srv
```

サーバ本体は mise のグローバル、proc-macro は**プロジェクトが pin した 1.85.0**。狙いどおり。

**宣言順が挙動を決める**: mise は `[tools]` の宣言順に PATH を前置する。`installs/rust/<version>` はすべて `~/.cargo/bin` への symlink で、そこには active toolchain に component を持たない rustup の `rust-analyzer` proxy がいる。よって `rust-analyzer` を `rust` より**前**に宣言しないと必ず起動失敗する。

**即失敗**: `MISE_EXEC_AUTO_INSTALL=0` / `MISE_NOT_FOUND_AUTO_INSTALL=0` を LSP 起動時のみ渡す。未導入の `rust = "1.80.0"` を pin したリポジトリで、rust 1.80.0 が**インストールされないまま**であることを確認した（エディタ内で数分ブロックしない）。`vim.system` の `env` は現在の環境にマージされるので PATH は保たれる。

**採用した spec**（実測値で固定）:

| 用途 | spec | 版 |
| --- | --- | --- |
| rust | `rust-analyzer` | 2026-07-27 |
| lua | `lua-language-server` | 3.18.2 |
| c++ | `ubi:clangd/clangd` | 22.1.6 |
| json / css / html / eslint | `npm:vscode-langservers-extracted` | 4.10.0 |
| react | `npm:typescript-language-server` | 5.3.0 |
| yaml | `npm:yaml-language-server` | 1.24.0 |
| tailwind | `npm:@tailwindcss/language-server` | 0.16.0 |
| copilot | `npm:@github/copilot-language-server` | 1.526.0 |
| python | `npm:basedpyright` | 1.39.9 |
| ruby | `gem:ruby-lsp` | 0.26.10 |
| go | `go:golang.org/x/tools/gopls` | 0.23.0 |
| go | `go:golang.org/x/tools/cmd/goimports` | 0.48.0 |
| go | `gofumpt` / `golangci-lint` | latest |
| haml | `gem:haml_lint` | 0.76.0 |
| ランタイム | `ruby` / `go` | 4.0.1 / 1.26.5 |

**`ruby` と `go` をグローバルに置くのは避けられない**。`gopls` にプリビルドバイナリが存在せず（`ubi:golang/tools` のリリースはアセット 0 件）`go:` バックエンドでビルドするしかなく、`lsp/gopls.lua` の root 検出も nvim の環境で `go env` を実行する。`gem:` バックエンドは ruby 無しでは機能しない（宣言前は `ruby --version` が `No version is set for shim: ruby` で失敗していた）。これらは解析主体ではなく、バックエンドのビルド土台とプロジェクト外ファイルのフォールバック。

**採用しなかったもの**: `npm:typescript` のグローバル宣言。7.0.2 は native 版で `tsserver.js` を持たず `typescript-language-server` から使えない。加えて `tsserver.path` でグローバルを強制するとプロジェクトのバージョンを無視してしまう。ts_ls は解析対象の typescript をプロジェクトの `node_modules` から取る前提のままにした（**プロジェクトに typescript が無い単体 `.ts` ファイルでは ts_ls が `initialize` で失敗する**）。

**gem の注意点**: gem 系ツールはインストール時の ruby に紐づく。プロジェクトが別の ruby を pin すると噛み合わない可能性があるため、`Gemfile.lock` に `ruby-lsp` があれば `bundle exec` 経由で起動する（`lua/lib/project.lua` の `bundles`）。なお ruby-lsp は Gemfile があって Gemfile.lock が無いと起動を拒否する（実測、`bundle install` を促すメッセージを出す）。

## Finding 4: nvim-lint の `biomejs` が無条件実行かつディスク内容を lint していた（対応済み）

修正前、`lua/plugins/nvim-lint.lua` は ts / tsx / js / jsx / json / jsonc / css に対して**無条件**に `biomejs` を設定していた。一方で biome LSP は `workspace_required = true` ＋ `root_dir` で biome 設定の実在を要求し、conform は独自に `biome.json(c)` の有無を見ていた。**3 者で適用条件が食い違っていた**。

### 影響

- **biome を使わないプロジェクトに biome のルールが混入する**。prettier / eslint 構成のリポジトリで、conform は prettier で整形しつつ nvim-lint が `biome lint` の診断を出す。整形とリントが別流派で殴り合う。
- **biome プロジェクトでは診断が二重になる**。biome LSP と nvim-lint が同じ内容を報告する。
- conform 側の判定は `biome.json` / `biome.jsonc` だけを見ており、lspconfig が見る `package.json` の `biomejs` 宣言を**見落としていた**。package.json で biome を設定したプロジェクトでは LSP は attach するのに conform は biome を選ばない。
- `linters/biomejs.lua:36-38` は `stdin = false` で、`lint.lua:383` がファイル名を渡す。つまり **ディスク上の内容を lint する**。`lua/config/autocmds.lua` の auto-save は `BufLeave` / `FocusLost` でしか保存しないため、契機に入っていた `InsertLeave` 時点の診断は**構造的に必ず古い**。

### 対応方針

`lua/lib/project.lua` を新設し、判定を 1 箇所に集めた（`uses_biome` / `uses_prettier` / `root_has` / `root_file_contains`）。`conform.lua` の `root_has` はここへ移し、conform と nvim-lint の両方から使う。

- 判定条件を lspconfig の `lsp/biome.lua` に揃え、`biome.json(c)` に加えて `package.json` / `package.json5` の `biomejs` 宣言も見る。LSP・formatter・linter の 3 者で条件が一致した。
- nvim-lint は buffer ごとに `biomejs` をゲートし、biome 非採用プロジェクトでは走らせない。
- lint 契機から `InsertLeave` を外し、`BufReadPost` / `BufWritePost` に限った。

一時 git リポジトリ 3 種で実測：設定なし → `run={}`、`biome.json` → `run={biomejs}`、`package.json` 宣言 → `run={biomejs}`。

## Finding 5: tailwindcss / cssls の過剰 attach と多重診断（対応済み）

`nvim --headless README.md` を本リポジトリで実行すると、修正前は `copilot` と **`tailwindcss`** が attach していた。CSS が 1 行も無いリポジトリである。

原因は lspconfig の `lsp/tailwindcss.lua`。`filetypes` が約 50 種あり `markdown` / `mdx` / `php` / `clojure` / `haml` などを含む。さらに `root_files` の末尾が tailwind v4 向けフォールバックの **`.git`** なので、`workspace_required = true` も満たしてしまう。

### 影響

- **git リポジトリごとに node プロセスが 1 つ無駄に立つ**。markdown を開くだけで起動する。
- `cssls` は既定で `css/scss/less.validate = true`。tailwind の `@apply` / `@tailwind` を未知の at-rule として報告する古典的な衝突が起きる。css では `cssls` ＋ `tailwindcss` ＋（biome プロジェクトなら）`biome` で**診断源が最大 3 つ**になる。

### 対応方針

- `tailwindcss` の `filetypes` を実際に使う 12 種（css / less / postcss / sass / scss / html / js / jsx / ts / tsx / svelte / vue）に絞った。
- `root_dir` を上書きし、`.git` フォールバックをやめて tailwind / postcss の設定ファイル、または `package.json` の `tailwindcss` 宣言を必須にした（v4 でも動く）。
- `cssls` の `css/scss/less.validate` を `false` にし、多重診断を止めた。

修正後、`README.md` の attach は `copilot` のみ。

## Finding 6: `clang_format` が非推奨エイリアスでバイナリも不在だった（対応済み）

`lua/plugins/conform.lua` は cpp / c に `clang_format` を指定していた。`conform/formatters/clang_format.lua:3` は `conf.meta.deprecated = true` で、正名は `clang-format`。

さらに **バイナリが 3 層すべてに存在しなかった**。mise にも nix にも無く、mason の clangd パッケージが link するのは `clangd` だけ。

`conform/init.lua:795-797` は利用不能な formatter を `log.debug` に落とすだけで通知しない。`:512-521` がそのまま `lsp_format = "fallback"` へ流すため、**cpp / c は clangd の LLVM 既定で整形されていた**。指定した覚えのない整形規則が黙って適用されていた状態。

### 影響

`.clang-format` を置いても、置いていない状態と区別がつかない。整形結果が LLVM スタイル固定で、プロジェクトの規約に従わない。

### 対応方針

- `clang_format` → `clang-format` に改名。
- `config.unix.toml` に `clang-format = "latest"` を追加（mise registry にあり、22.1.8 が入る）。`AGENTS.md` の「ユーザーツールは mise」方針に沿う唯一の選択肢。

`mise install` 後、conform で `clang-format available=true` を確認した。Windows 側は Finding 8 として未対応のまま。

## Finding 7: lua_ls の `workspace.library` が起動順依存だった（対応済み）

修正前は `library = vim.api.nvim_get_runtime_file("", true)`。この式は `nvim-lspconfig` の `config()`、つまり**起動時**に評価される。eager ロードされるプラグインは `nvim-lspconfig` / `nvim-treesitter` / colorscheme / `snacks.nvim` の 4 つだけなので、その時点の rtp は小さい。

実測で **12 件**（うちプラグイン 7 件）。後の rtp は 24 件、プラグインは全 35 個。

### 影響

- lua_ls は `blink.cmp` / `conform.nvim` / `snacks.nvim` などの型を**知らない**。`lua/plugins/blink.lua:18-19` の `---@module "blink.cmp"` 注釈も解決されない。
- 含まれる 7 件が「たまたま起動時にロード済みだったもの」なので、プラグイン構成やロード契機を変えると**予告なく中身が変わる**。

### 対応方針

固定 3 パス（`$VIMRUNTIME/lua`、`vim.fn.stdpath("config") .. "/lua"`、`${3rd}/luv/library`）に置き換えた。vim API と自分の設定は確実にカバーし、ロード順に依存しない。

プラグイン自体の型が必要なら `lazydev.nvim`（ロード済みプラグインを動的に library へ追加する）が本来の解。プラグイン追加になるため今回は入れていない。`checkThirdParty = false` は妥当なので維持。`.luarc.json` が無いのは無害で、`stylua.toml` が lua_ls の `root_markers` に含まれるため root は正しく解決される。

## Finding 8: Windows で LSP / formatter が成立しない（要判断・未対応）

`mise/dotfiles/mise/config.windows.toml` は 14 tools で、formatter は `stylua` のみ。`README.md:25-26` は「Windows は単一の `windows` 環境で Neovim、PowerShell profile、Windows 用 CLI、通常の dotfiles を管理する」と明記しており、Neovim は正式な管理対象。

### 影響

- **mason の 12 本のうち 9 本が npm パッケージ**（typescript-language-server / yaml-language-server / vscode-langservers-extracted ×3 / pyright / tailwindcss / copilot / biome）。`config.windows.toml` に **node が無い**ため導入できない。`python` も `rust` も無い。
- conform と nvim-lint が要求する `prettier` / `biome` / `ruff` / `yamllint` がすべて欠けている。`clang-format` も今回 unix 側にしか入れていない。
- `:18` が `neovim = "latest"` で**未固定**。unix は 0.12.4 固定。設定は `vim.lsp.inline_completion` など 0.12 専用 API を使っているので、`latest` が上がった瞬間に unix と挙動が乖離しうる。
- `mise/mise.windows.toml:3` は `~/.config/nvim` を `mode = "copy"` で配る。lazy.nvim が `lazy-lock.json` に書き戻しても repo に反映されず、静かに乖離する。

### 対応方針

**Finding 3 の対応で悪化した。** mason を撤去したため、サーバの宣言は `config.unix.toml` にしか無い。Windows は `config.windows.toml` を読むので、同じ宣言を書かない限り**サーバは 0 本**になる。従来は mason があるぶん「node を入れれば動く」余地があった。

Windows で nvim をどこまで使うかの判断が先。フル開発環境にするなら `node` / `python` / `rust` / `go` / `ruby` とサーバ群・formatter 群を `config.windows.toml` に追加し、`neovim` を unix と同じ版に固定する。エディタとしてだけ使うなら、Windows では LSP を絞る旨を文書化する。いずれも未実施。

## Finding 9: リポジトリ自身の言語が未カバーで、formatter 設定も未追跡（要判断・未対応）

追跡ファイル 106 件の拡張子内訳は lua 49 / toml 12 / md 9 / ps1 8 / zsh 5 / sh 4 / nix 3 / json 3。

### 影響

- **LSP と formatter が揃っているのは lua だけ**。toml 12 件に taplo が無く、shell 9 件に shellcheck / shfmt が無く、nix 3 件に LSP も formatter も無い。`scripts/update-wsl.sh:1` は `# shellcheck shell=bash` というディレクティブを持つが、shellcheck はどの層にも無い。`AGENTS.md:23` は `nix flake check` を必須としているのに nix の LSP / formatter は無い。
- 逆に、**mason の 12 本は追跡ファイルが 0 件の言語を対象にしている**（rust / python / c / cpp / css / html)。供給しているものと実際に書くものがほぼ噛み合っていない。
- **追跡されている formatter 設定は `stylua.toml` 2 件のみ**。yaml を prettier で整形する一方、リントは yamllint の既定ルールに任せているため、`document-start`（`---` を要求するが prettier は付けない）、`truthy`（Actions の `on:`）、`line-length` 80 が発火する。**どの formatter でも解消できない警告**が出る組み合わせになっている。

### 対応方針

mise で `taplo` 0.10.0 / `shellcheck` 0.11.0 / `shfmt` 3.13.1 が供給可能（実測）。nix の formatter は mise registry に無く、既にベース層である nix 側で入れるのが素直。`.yamllint` を追跡して既定ルールを prettier の出力に合わせるのも同時に必要。ただしこれは「このリポジトリを編集する体験」の話で LSP 層の不具合ではないため、範囲を分けて未実施とした。

## Finding 10: 無効・冗長な設定（対応済み）

| # | 内容 | 該当箇所 | 対応 |
| --- | --- | --- | --- |
| 1 | **`vim.lsp.config("copilot", {})` が空呼び出しの no-op で、lspconfig 既定の `telemetry.telemetryLevel = "all"` が素通ししていた** | 旧 `lsp.lua:93` | `telemetryLevel = "off"` を明示（`lsp.lua:157`） |
| 2 | `settings.redhat.telemetry.enabled = false` は lspconfig の yamlls 既定と同一 | 旧 `lsp.lua:36-42` | 削除 |
| 3 | `vim.lsp.config("ts_ls", {})` が空の deep-merge で no-op | 旧 `lsp.lua:77` | 削除 |
| 4 | `schemastore.nvim` を依存に持ちながら `json.schemas()` 未使用。`jsonls` は有効なのに既定のまま | `lsp.lua:11` | `jsonls` に適用（`lsp.lua:52`） |
| 5 | yamlls の `validate` / `completion` / `hover` はサーバ既定と同値 | 旧 `lsp.lua:44-46` | 削除 |

①だけは挙動が変わる（テレメトリ送信の停止）ので他と分けて扱った。

なお `lua/plugins/tiny-inline-diagnostic.lua:7` の `vim.diagnostic.config({ virtual_text = false, virtual_lines = false })` は 0.12 の既定（`$VIMRUNTIME/lua/vim/diagnostic.lua:393-399`）と同一で、その意味では冗長。ただし **tiny-inline-diagnostic 自身はこの設定を行わない**（`vim.diagnostic.config()` を読むだけ）ため、この行はプラグインの前提を明示する唯一の箇所になっている。既定が変わったときの保険として**あえて残した**。

## 良い点

評価上、意図的で妥当と判断した設計。

- **LSP 設定が `lua/plugins/lsp.lua` 1 ファイルに集約**されている。`lspconfig[...].setup{}` を使わず `vim.lsp.config` / `vim.lsp.enable` の 0.11+ API に統一されており、`lsp/<server>.lua` と二重管理になっていない。
- **`conform.lua` の `web_formatters` が設定ファイルの実在で prettier / biome を動的に選ぶ**。プロジェクトごとに正しい formatter が選ばれる。判定を `lua/lib/project.lua` に移した後もこの設計は維持している。
- **`format_on_save` のガードが実用的**（1 MiB 超・無名バッファ・terminal 系 filetype を除外）。
- **`lua/config/autocmds.lua:43-47` が copilot の全 filetype attach を把握している**。`textDocument/documentSymbol` を持つクライアントだけにシンボル移動キーを張っており、コメントで理由まで書かれている。
- **pyright と ruff の分担が正しい**。ruff を LSP として立てず型検査は pyright、リント / 整形は ruff CLI という切り分けで、診断が重複しない。
- **`rust_analyzer` の `check.command = "clippy"`** は素直な選択。
- **`stylua.toml` を追跡している**。これは lua_ls の `root_markers` にも含まれるため、root 解決にも効いている。
- **mason-lspconfig の `dependencies` 宣言が公式手順どおり**（mason.nvim と nvim-lspconfig）。今回 `vim.lsp.enable` をこの `config` に置けたのはこの依存関係が正しかったおかげ。

## 補足（好みの範囲）

- lspconfig の lua_ls 既定は `codeLens.enable = true` と `hint.enable = true` を送るが、設定に `vim.lsp.inlay_hint` / `vim.lsp.codelens` / `vim.lsp.document_color` の呼び出しが無いため**要求しているのに表示されない**。使うならトグルのキーマップを、使わないなら要求を切るのが筋。
- `rust_analyzer` の `cargo.allFeatures = true` は大きな workspace で解析が重くなる。今のところ rust の追跡ファイルは 0 件なので実害はない。
- `ts_ls` は `typescript` がプロジェクトに無いと `initialize` で失敗し、エラーを出して終了する（合成リポジトリで確認）。`node_modules` が入っている実プロジェクトでは問題にならないが、雑に開いた `.ts` 単体ファイルではエラーが出る。

## Action Summary

| 区分 | 件数 | 対象 | 状態 |
| --- | --- | --- | --- |
| 修正（重大） | 2 | Finding 1（yamlls の settings）、Finding 2（有効サーバの宣言） | 対応済み |
| 修正 | 4 | Finding 4（biome の適用条件）、Finding 5（過剰 attach）、Finding 6（clang-format）、Finding 7（lua_ls library） | 対応済み |
| 整理 | 5 | Finding 10 の無効・冗長な設定 | 対応済み |
| 要判断 | 1 | Finding 3（mason 供給層 → mise へ移行） | 対応済み |
| 要判断 | 2 | Finding 8（Windows）、Finding 9（repo 自身の言語） | 未対応 |

残る 2 件はいずれも方針判断を伴う。Finding 8 は Finding 3 の対応で悪化しているため優先度が上がった。

`~/.local/share/nvim/mason` の 1.2 GB（copilot-language-server 473M、clangd 220M、css/html/json-lsp 各 95M）はオーファンとして残っている。新構成で全言語の LSP が動くことを確認した上で `rm -rf ~/.local/share/nvim/mason` で回収できる。

## Notes

- 評価時点: Neovim 0.12.4、`lazy-lock.json` は 35 エントリ、mason パッケージ 12 件（biome 2.5.3 / clangd 22.1.6 / lua-language-server 3.18.2 / rust-analyzer 2026-07-06 ほか）、mise の biome 2.5.4。
- 検証は `$VIMRUNTIME` のランタイム、`~/.local/share/nvim/lazy` のプラグインソース読解、および headless 実行での実測で行った。Web 上の記事は参照していない。mise 側の供給可能性のみ `mise ls-remote`（npm / aqua / ubi レジストリ）に問い合わせた。
- **`docs/nvim-completion-audit.md` の Finding 1（blink の `'*'` capabilities が LSP クライアントに届かない）は同じ `lua/plugins/lsp.lua` に関わるが別問題**。`$VIMRUNTIME/lua/vim/lsp.lua:341-362` のマージ順で `'*'` は最下位なので、本ドキュメントの修正とは競合しない。未対応のまま同ドキュメントの管轄。
- 同様に、**廃止済み AI プラグイン（`codecompanion` / `pane-tabs-ai`）の死んだ filetype 分岐**は `lua/plugins/lsp.lua:14-17,165-175`、`conform.lua`、`nvim-lint.lua` に残っているが、`docs/nvim-completion-audit.md` の Finding 6 の管轄なので本ドキュメントでは触っていない。
- `~/.local/share/mise/shims/clangd` が存在するが、`config.unix.toml` に `clangd` の宣言は無い。追跡されないローカル残骸。
- 現存する nvim 関連ドキュメントは本ファイルと `docs/nvim-ai-integration.md`、`docs/nvim-completion-audit.md` の 3 件。`nvim-completion-audit.md:215` が参照する `docs/nvim-plugin-audit.md` と `docs/nvim-rebuild.md` は commit `d8d9abf` で削除済みでリンクが切れている。
