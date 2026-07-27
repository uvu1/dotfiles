# Neovim プラグイン棚卸し

## Summary

- 対象は `mise/dotfiles/.config/nvim`。lazy.nvim 管理。棚卸し時点で **44 プラグイン**（`lazy.nvim` 自身を含む）、うち 4 件を削除済みで**現在 40 プラグイン**。
- 最大の問題は **treesitter 系が丸ごと機能していない**こと。`nvim-treesitter` にトップレベル spec が無く、パーサが 1 つもインストールされていない。依存する 4 プラグインが実作業言語で全滅している。
- 明確に不要なもの（Neovim の組み込み機能・snacks.nvim 内蔵機能と重複）が **4 件**（すべて対応済み）、条件付きで不要なものが **1 件**（`Comment.nvim`）。
- 機能重複でどれか一つに寄せるべきものが **1〜2 件**。
- メンテナンス停止プラグインが **1 件**。
- 削除とは別に、設定バグ・デッドコードが **9 件**。
- 全て整理した場合の想定は 44 → **37〜38 プラグイン**（`nvim-treesitter-textobjects` は `vaf` `dif` 目的で残す方針に決定）。
- **別セッションへの引き継ぎは「Handoff: treesitter 復活と textobjects 導入」を参照。**

以降、ファイルパスは断りが無い限り `mise/dotfiles/.config/nvim/` からの相対パス。

## Progress

| 項目 | 区分 | 状態 |
| --- | --- | --- |
| `nvim-web-devicons` | 削除（争いなし） | **対応済み** |
| `nvim-notify` | 削除（争いなし） | **対応済み** |
| `lazygit.nvim` | 削除（争いなし） | **対応済み** |
| `mini.bracketed` | 削除（争いなし） | **対応済み** |
| 関数・クラスの LSP 移動（`]m` `[m` `]]` `[[`） | 新規追加 | **対応済み** |
| `Comment.nvim` | 削除（条件付き） | 未対応・要判断 |
| `trouble.nvim` | 削除（重複解消） | 未対応 |
| `treesj` | 削除（重複解消・優先度低） | 未対応 |
| `auto-save.nvim` | 置換 | 未対応 |
| `nvim-treesitter` の spec 新設＋パーサ導入 | 新規追加 | 未対応（Handoff 参照） |
| `nvim-treesitter-textobjects` の select 導入（`vaf` `dif`） | 新規追加 | 未対応（Handoff 参照） |
| Finding 5 の設定バグ 9 件 | 修正 | 未対応 |

## Verified Facts

推測ではなく実測した内容。

| 検証項目 | 方法 | 結果 |
| --- | --- | --- |
| Neovim バージョン | `nvim --version` | **0.12.4**（`mise/mise.toml:13` が `neovim = "latest"`） |
| インストール済み treesitter パーサ | `nvim --headless -c 'lua ... vim.api.nvim_get_runtime_file("parser/*", true)'` | **Neovim 同梱の 7 つのみ**（`c` `lua` `markdown` `markdown_inline` `query` `vim` `vimdoc`）。`~/.local/share/nvim/lazy/nvim-treesitter/parser` と `~/.local/share/nvim/site/parser` はいずれも不在 |
| textobjects の API パス | `ls ~/.local/share/nvim/lazy/nvim-treesitter-textobjects/lua/` | `nvim-treesitter-textobjects/` のみ存在。**`nvim-treesitter/textobjects/` は存在しない** |
| snacks.nvim の内蔵モジュール | `ls ~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/` | `lazygit.lua` `terminal.lua` `notifier.lua` `picker/` `explorer/` を確認 |
| noice の notify view の backend | `noice/config/views.lua:66-72` | **`backend = { "snacks", "notify" }`, `fallback = "mini"`**。`View.get_view` はリスト順に `is_available()` を試して最初に通ったものを返す（`noice/view/init.lua:49,71-75`） |
| noice snacks backend の可用性 | `require("noice.view.backend.snacks")({}):is_available()` | **true**（`_G.Snacks ~= nil and Snacks.config.notifier.enabled` を満たす）。よって **nvim-notify は元から一度もインスタンス化されていなかった** |
| 実際にインストール済みのプラグイン | `ls ~/.local/share/nvim/lazy/` | 棚卸し時点で `lazy-lock.json` の 44 件と一致。4 件削除後は 40 件 |
| `mock_nvim_web_devicons()` の実装 | `rg -n -A40 'mock_nvim_web_devicons' .../mini.icons/lua/mini/icons.lua` | `package.preload['nvim-web-devicons']` に mock を登録（既ロード時は `package.loaded` を上書き）。`get_icon_by_filetype` を含む API を提供 |
| ftplugin による `]]` `[[` `]m` `[m` の奪取 | `rg -l 'map <buffer>.*\]\]' $VIMRUNTIME/ftplugin/` | 同梱 ftplugin **21 個**（`python` `rust` `go` `php` `ruby` `markdown` `vim` ほか）が定義。`ftplugin/python.vim:69-79` の実測で **n / o / x の 3 モードすべて**。バッファローカルは常にグローバルより優先される。`af` `if` `ac` `ic` は誰も使っていない |
| `vim.treesitter.start()` を呼ぶ同梱 ftplugin | `rg -l 'treesitter.start' $VIMRUNTIME/ftplugin/` | **`help.lua` `lua.lua` `markdown.lua` `query.lua` の 4 つだけ**。Neovim 0.12 は treesitter を自動有効化しないので、Python / Rust / TypeScript は自分で `start()` を呼ぶ必要がある |
| `nvim-treesitter` main の公開 API | `rg -n '^function M\.' nvim-treesitter/lua/nvim-treesitter/init.lua` | `setup` `install` `update` `get_installed` `get_available` `uninstall` `indentexpr`。**`ensure_installed` は無い**（master ブランチの記法は使えない） |
| Neovim 組み込みマッピング | `:h default-mappings`（`doc/vim_diff.txt:140-176`） | `gc` `gcc` `v_gc` `o_gc` / `]d` `[d` `]D` `[D` / `[q` `]q` `[Q` `]Q` / `[b` `]b` `[l` `]l` `[t` `]t` `[a` `]a` `[<Space>` `]<Space>` が組み込み。**`gb` 系（ブロックコメント）は存在しない** |

## Inventory

判定欄の凡例: **維持** / **削除** / **置換** / **要修正** / **依存**（他プラグインの `dependencies` としてのみ存在）。

### 管理

| プラグイン | 宣言箇所 | ロード契機 | 判定 |
| --- | --- | --- | --- |
| `folke/lazy.nvim` | `lua/config/lazy.lua:1-39` | bootstrap | 維持 |

### テーマ・UI

| プラグイン | 宣言箇所 | ロード契機 | キーマップ | 判定 |
| --- | --- | --- | --- | --- |
| `uvu1/kawaii-theme.nvim` | `lua/plugin/ui.lua:3` | `lazy=false`, priority 1000 | — | 維持（自作） |
| `folke/noice.nvim` | `lua/plugin/ui.lua:16` | `VeryLazy` | — | 要修正 |
| `MunifTanjim/nui.nvim` | `lua/plugin/ui.lua:64` | noice 依存 | — | 依存 |
| ~~`rcarriga/nvim-notify`~~ | ~~`lua/plugin/ui.lua:65`~~ | ~~noice 依存~~ | — | **削除済み** |
| `nvim-lualine/lualine.nvim` | `lua/plugin/lualine.lua:3` | `VeryLazy` | — | 維持 |
| ~~`nvim-tree/nvim-web-devicons`~~ | ~~`lua/plugin/lualine.lua:5`~~ | ~~lualine 依存~~ | — | **削除済み** |
| `nvim-mini/mini.icons` | `lua/plugin/minis.lua:18` | `VeryLazy` | — | 維持 |

### ピッカー・エクスプローラ

| プラグイン | 宣言箇所 | ロード契機 | キーマップ | 判定 |
| --- | --- | --- | --- | --- |
| `folke/snacks.nvim` | `lua/plugin/snacks.lua:3` | `lazy=false`, priority 1000 | `<leader>e` `<leader>E` `<leader>f*` `<leader>g*` `<leader>s*` `<leader>dl` | 維持（中核） |

有効サブモジュール: `bigfile` `quickfile` `dashboard` `explorer` `picker` `indent` `scope` `statuscolumn` `input` `notifier`。
`lua/config/autocmd/vimenter.lua` が引数なし起動時に explorer を自動オープンする。

### LSP・診断

| プラグイン | 宣言箇所 | ロード契機 | キーマップ | 判定 |
| --- | --- | --- | --- | --- |
| `neovim/nvim-lspconfig` | `lua/plugin/lsp.lua:8` | `lazy=false` | — | 維持 |
| `mason-org/mason.nvim` | `lua/plugin/lsp.lua:3` | 遅延 | — | 維持 |
| `mason-org/mason-lspconfig.nvim` | `lua/plugin/lsp.lua:124` | `VeryLazy`, `BufReadPre` | — | 維持 |
| `b0o/schemastore.nvim` | `lua/plugin/lsp.lua:11` | lspconfig 依存 | — | 依存 |
| `rachartier/tiny-inline-diagnostic.nvim` | `lua/plugin/tiny-inline-diagnostic.lua:3` | `LspAttach` | — | 維持 |
| `folke/trouble.nvim` | `lua/plugin/trouble.lua:3` | `cmd = "Trouble"` | `<leader>xx` `<leader>xX` `<leader>xQ` `<leader>cs` `<leader>cl` | **削除**（重複） |
| `stevearc/aerial.nvim` | `lua/plugin/aerial.lua:3` | `LspAttach` / keys | `<leader>o`、および `]m` `[m` `]]` `[[`（LspAttach でバッファローカル） | 維持 |

`ensure_installed`: `copilot` `lua_ls` `rust_analyzer` `ts_ls` `biome` `jsonls` `yamlls` `html` `cssls` `tailwindcss` `pyright`。

### 補完

| プラグイン | 宣言箇所 | ロード契機 | 判定 |
| --- | --- | --- | --- |
| `saghen/blink.cmp` | `lua/plugin/blink.lua:3` | `InsertEnter` `CmdlineEnter` | 要修正 |
| `saghen/blink.lib` | `lua/plugin/blink.lua:8` | blink 依存 | 依存 |
| `rafamadriz/friendly-snippets` | `lua/plugin/blink.lua:9` | blink 依存 | 依存 |

### treesitter

| プラグイン | 宣言箇所 | ロード契機 | キーマップ | 判定 |
| --- | --- | --- | --- | --- |
| `nvim-treesitter/nvim-treesitter` | **トップレベル spec なし** | 他 4 件の `dependencies` 経由のみ | — | **要修正（新規 spec）** |
| `nvim-treesitter/nvim-treesitter-context` | `lua/plugin/treesitter-context.lua:3` | `BufReadPost` | — | 維持（要パーサ） |
| `nvim-treesitter/nvim-treesitter-textobjects` | `lua/plugin/treesitter-textobjects.lua:3` | keys | `]f` `[f` `]F` `[F`（破損） | **残す**（`vaf` `dif` 目的、Handoff 参照） |
| `HiPhish/rainbow-delimiters.nvim` | `lua/plugin/rainbow-delimiters.lua:3` | `BufReadPost` `BufNewFile` | — | 維持（要パーサ） |

### 編集

| プラグイン | 宣言箇所 | ロード契機 | キーマップ | 判定 |
| --- | --- | --- | --- | --- |
| `nvim-mini/mini.pairs` | `lua/plugin/minis.lua:3` | `InsertEnter` | `<CR>` (i) | 維持 |
| `nvim-mini/mini.surround` | `lua/plugin/minis.lua:13` | `InsertEnter` | `sa` `sd` `sr` 他（既定） | 要修正（`s` 衝突） |
| ~~`nvim-mini/mini.bracketed`~~ | ~~`lua/plugin/minis.lua:26`~~ | ~~`VeryLazy`~~ | ~~`]d` `[d` `]q` `[q`~~ → 組み込みへ | **削除済み** |
| `numToStr/Comment.nvim` | `lua/plugin/comment.lua:9` | `VeryLazy` | `<leader>cc` `<leader>cb` | 削除（条件付き） |
| `folke/ts-comments.nvim` | `lua/plugin/comment.lua:3` | `VeryLazy` | — | 維持 |
| `Wansmer/treesj` | `lua/plugin/treesj.lua:2` | keys | `<leader>ts` | 削除候補（優先度低） |
| `folke/flash.nvim` | `lua/plugin/flash.lua:3` | `VeryLazy` | `s` `S` `r` `R` `<C-s>` | 維持 |
| `Pocco81/auto-save.nvim` | `lua/plugin/auto-save.lua:3` | `InsertLeave` | — | **置換** |
| `kevinhwang91/nvim-ufo` | `lua/plugin/ufo.lua:3` | `BufReadPost` | `zR` `zM` `zp` | 維持（要パーサ） |
| `kevinhwang91/promise-async` | `lua/plugin/ufo.lua:4` | ufo 依存 | — | 依存 |
| `stevearc/conform.nvim` | `lua/plugin/conform.lua:50` | `BufWritePre` | `<leader>cf` | 維持 |
| `mfussenegger/nvim-lint` | `lua/plugin/nvim-lint.lua:3` | `BufReadPost` `BufWritePost` `InsertLeave` | — | 維持 |

### Git

| プラグイン | 宣言箇所 | ロード契機 | キーマップ | 判定 |
| --- | --- | --- | --- | --- |
| `lewis6991/gitsigns.nvim` | `lua/plugin/gitsign.lua:3` | `VeryLazy` | `<leader>db` `<leader>dB` | 要修正（未活用） |
| `sindrets/diffview.nvim` | `lua/plugin/diffview.lua:3` | cmd / keys | `<leader>dd` `<leader>dm` `<leader>dh` `<leader>df` `<leader>dt` `<leader>dq` | 維持 |
| ~~`kdheepak/lazygit.nvim`~~ | ~~`lua/plugin/lazygit.lua:2`~~ | ~~cmd / keys~~ | `<leader>tl` → snacks へ移設 | **削除済み** |
| `nvim-lua/plenary.nvim` | `lua/plugin/lazygit.lua:5`, `lua/plugin/codecompanion.lua:39` | 依存 | — | 依存（codecompanion が継続利用） |

### ターミナル・タスク

| プラグイン | 宣言箇所 | ロード契機 | キーマップ | 判定 |
| --- | --- | --- | --- | --- |
| `akinsho/toggleterm.nvim` | `lua/plugin/toggleterm.lua:85` | cmd / keys | `<leader>tt` | 維持 |
| `stevearc/overseer.nvim` | `lua/plugin/overseer.lua:3` | cmd / keys | `<leader>rr` `<leader>rt` `<leader>ra` `<leader>rl` `<leader>ri` | 維持 |

`lua/overseer/template/user/just.lua` で justfile のレシピを task 化するカスタムテンプレートを持つ。

### AI

| プラグイン | 宣言箇所 | ロード契機 | キーマップ | 判定 |
| --- | --- | --- | --- | --- |
| `olimorris/codecompanion.nvim` | `lua/plugin/codecompanion.lua:34` | `cmd = "CodeCompanionChat"` | — | 維持 |
| `uvu1/pane-tabs.nvim` | `lua/plugin/pane-tabs.lua:4` | `VeryLazy` / cmd / keys | `<M-[>` `<M-]>` `<leader>a1..a3` `<leader>aa` `<leader>aq` `<leader>al` `<leader>as` | 維持（自作） |

### その他

| プラグイン | 宣言箇所 | ロード契機 | キーマップ | 判定 |
| --- | --- | --- | --- | --- |
| `folke/which-key.nvim` | `lua/plugin/whichkey.lua:2` | `VeryLazy` | `<leader>?` | 維持 |

## Finding 1: treesitter 系が丸ごと機能していない（最優先）

`nvim-treesitter` にトップレベル spec が存在しない。取得経路は以下の `dependencies` のみ。

- `lua/plugin/treesitter-context.lua:11`
- `lua/plugin/treesitter-textobjects.lua:4`
- `lua/plugin/rainbow-delimiters.lua:5`
- `lua/plugin/codecompanion.lua:40`

`lazy-lock.json` の `nvim-treesitter` は `"branch": "main"`。main ブランチは `require("nvim-treesitter").install(...)` を明示的に呼ばない限りパーサを一切インストールしない。設定内に `install()` の呼び出しも `vim.treesitter.start()` も存在しない（`rg -n 'treesitter'` で全件確認済み）。結果として、実測どおり **パーサは Neovim 同梱の 7 つのみ**。

LSP・conform・nvim-lint が対象にしている実作業言語（TypeScript / TSX / JavaScript / Rust / Python / JSON / YAML / CSS）で、以下が全て無効になっている。

- `nvim-treesitter-context` — コンテキスト行が一切出ない
- `rainbow-delimiters.nvim` — 括弧の色付けが効かない
- `nvim-ufo` — `provider_selector` の `"treesitter"` が外れ `"indent"` にフォールバック（`lua/plugin/ufo.lua:8`）
- `flash.nvim` の `S` / `R`（`lua/plugin/flash.lua:9,11`）
- `aerial.nvim` の `treesitter` バックエンド（`lua/plugin/aerial.lua:5`）— 現状は `lsp` バックエンドのみで動作

加えて、**パーサを入れても現状の `nvim-treesitter-textobjects` のキーマップは動かない**。`lua/config/keymap/plugins/treesitter-textobjects.lua:5,9,13,17` が旧 API の `require("nvim-treesitter.textobjects.move")` を呼んでいるが、main ブランチの実体は `nvim-treesitter-textobjects.move`（Verified Facts で実測）。`]f` `[f` `]F` `[F` は module not found で必ず失敗する。

### 対応方針

未着手。手順は「Handoff: treesitter 復活と textobjects 導入」に詳細を書いた。

## Finding 2: 明確に不要なプラグイン

### 1. `mini.bracketed` — **対応済み**

`lua/plugin/minis.lua:26-47` で `buffer` `comment` `conflict` `indent` `jump` `location` `oldfile` `treesitter` `undo` `window` `yank` の suffix を全て空文字で無効化していた。生きているのは `diagnostic`（`]d` / `[d`）と `quickfix`（`]q` / `[q`）の 2 つだけ。

**この 2 つは Neovim が組み込みで提供している**。`:h default-mappings`（0.12.4）に `]d` `[d` `]D` `[D` と `[q` `]q` `[Q` `]Q` が明記されている（0.11 で追加）。加えて `[b` `]b`（buffer）`[l` `]l`（location list）`[t` `]t`（tag）`[a` `]a`（arglist）`[<Space>` `]<Space>`（空行挿入）も組み込み済みで、これらは元々この設定で無効化されている。

残存価値はゼロだったため spec ごと削除。検証: 削除後に `]d` `[d` が組み込みの `Jump to the next/previous diagnostic in the current buffer` に、`]q` `[q` が `:cnext` / `:cprevious` に解決されることを確認。

### 2. `nvim-web-devicons` — **対応済み**

`lua/plugin/lualine.lua:5` で lualine の `dependencies` として読まれていた。一方 `lua/plugin/minis.lua:17-24` の `mini.icons` が `MiniIcons.mock_nvim_web_devicons()` を実行しており、アイコン提供が二重になっていた。

**単純削除ではなく差し替えが必要だった理由**: `lua/config/lualine_pane/components.lua:67` が `require("nvim-web-devicons")` を直接呼んでいる。mock は `package.preload` に同名モジュールを登録するため require 自体は通るが、**mini.icons が先にロードされている必要がある**。lualine と mini.icons はどちらも `VeryLazy` で順序が保証されないため、依存に置いて mock が先に走ることを保証した。

```diff
-    dependencies = { "nvim-tree/nvim-web-devicons" },
+    dependencies = { "nvim-mini/mini.icons" },
```

検証: `nvim --headless "+Lazy! clean"` で `nvim-web-devicons` のみ削除（44 → 43）。`require("nvim-web-devicons")` が mock に解決されること、devicons を消費する `editor_language` コンポーネントが `󰢱 lua` を返すこと、ステータスライン全体が正常にレンダリングされること、クリーン起動でエラーが出ないことを確認済み。

### 3. `nvim-notify` — **対応済み**

`lua/plugin/ui.lua:65` で noice の `dependencies` として読まれていた。一方 `lua/plugin/snacks.lua:105` で `notifier = { enabled = true }`。通知バックエンドが二重に存在していた。

**調査の結果、noice の設定変更は不要だった**。noice の `notify` view は既定で `backend = { "snacks", "notify" }`（`noice/config/views.lua:66-72`）であり、`View.get_view` はリスト順に `is_available()` を試して最初に通ったものを返す（`noice/view/init.lua:49,71-75`）。snacks backend の可用条件は `_G.Snacks ~= nil and Snacks.config.notifier.enabled` で、この設定では満たされる。つまり **noice は元から snacks.notifier を使っており、`nvim-notify` は一度もインスタンス化されていなかった**。純粋な死荷重。

依存を snacks に差し替えるだけで済んだ。

```diff
     dependencies = {
       "MunifTanjim/nui.nvim",
-      "rcarriga/nvim-notify",
+      "folke/snacks.nvim",
     }
```

検証: `require("noice.view.backend.snacks")({}):is_available()` が `true`、`require("notify")` が失敗（＝完全に消えた）、`vim.notify()` が snacks.notifier に届き履歴に 1 件積まれることを確認済み。

### 4. `Comment.nvim`（**条件付き** — ブロックコメントを使うなら残す）

`lua/plugin/comment.lua:8-17`。**Neovim 0.10 以降が `gc` / `gcc` を組み込みで持つ**。さらに併存している `ts-comments.nvim`（`lua/plugin/comment.lua:3`）は、まさに**その組み込みコメント機能**の `commentstring` を treesitter 対応させるためのプラグイン。つまりライン コメントに関してはエンジンが二重になっている。

ただし **Neovim 組み込みにブロックコメントは無い**。`:h default-mappings`（0.12.4）の一覧は `gc` `gcc` `v_gc` `o_gc` のみで `gb` 系は存在せず、`commentstring` ベースのライン コメントだけを扱う。現在の設定は `toggler.block = "<leader>cb"` でブロックコメントを割り当てているため、**Comment.nvim を削除するとこの機能は失われる**。

判断は以下。

- ブロックコメントを使っていない → 削除可。`<leader>cc` を組み込みの `gcc` に割り当て直す
- 使っている → **残す**。ただし `ts-comments.nvim` との役割重複は残るので、どちらか一方に寄せる検討はする

副次的な効果として、Comment.nvim を削除すると Finding 5 #5 の衝突が解消し、AtCoder の `<leader>cb`（build-image）が復活する。

### 5. `lazygit.nvim` — **対応済み**

`snacks.nvim` が `Snacks.lazygit` を内蔵している（`snacks/lazygit.lua` を実測で確認）。フロート表示・カラースキーム連携・カレントファイル指定まで同等の機能を持ち、さらに **Neovim のカラースキームから lazygit のテーマを自動生成**し `os.editPreset = "nvim-remote"` を自動設定する点で上位互換。`M.meta` に `needs_setup` が無いオンデマンドモジュールなので setup も不要。

実施内容:

- `lua/plugin/lazygit.lua` を削除
- `lua/config/keymap/plugins/lazygit.lua` を削除し、`<leader>tl` を `lua/config/keymap/plugins/snacks.lua` へ移設（`require("snacks").lazygit.open()`）
- `lua/plugin/snacks.lua` の opts に `lazygit = {}` を追加（担当の明示）

`plenary.nvim` は codecompanion が引き続き必要とするため残る（残存を確認済み）。

検証: `Snacks.lazygit.open` が function として解決、`Snacks.config.lazygit.configure` が `true`、`<leader>tl` が desc `Toggle lazygit` で登録されることを確認。lazygit CLI は mise 管理の `0.63.1` が `PATH` 上に存在。

## Finding 2.5: 関数・クラスの LSP 移動を追加

`mini.bracketed` の削除とは別に、**LSP ベースの「次の関数（メソッド）」「次のクラス」移動**を新設した。

### 実装

`lua/config/symbol-nav.lua`（新規）が aerial のシンボルツリーを kind でフィルタして前後移動する。自前で `textDocument/documentSymbol` を投げるとキャッシュと `DocumentSymbol` / `SymbolInformation` の差異を扱う必要があるが、aerial は `backends = { "lsp", "treesitter", "markdown" }` で既にバッファへ追従しているのでその結果を使う。ジャンプ自体は `require("aerial.navigation").select_symbol()` に任せる（jumplist 記録・`selection_range` 優先・`highlight_on_jump` を含む）。

| kind グループ | 対象 SymbolKind |
| --- | --- |
| 関数・メソッド | `Function` `Method` `Constructor` |
| クラス | `Class` `Interface` `Struct` `Enum`（言語ごとのクラス等価物） |

### 調査で判明した 2 つの落とし穴

**1. aerial には独自の遅延ロードがある。** `on_attach` も `open_automatic` も無い設定では `lazy_load = true` と判定され、**autocmd を一切作らない**（`aerial/init.lua` の `setup`）。サイドバーを開くまでバックエンドが attach せず、`aerial.data` は空のままだった。サイドバーを開かずに使う用途なので `lazy_load = false` を明示し、併せて spec に `event = "LspAttach"` を追加した。

**2. グローバルマップでは ftplugin に勝てない。** Neovim 同梱の ftplugin **21 個**（`python.vim` `rust.vim` `go.vim` `php.vim` `ruby.vim` `markdown` `vim.vim` ほか）が `]]` `[[` `]m` `[m` をバッファローカルで定義しており、バッファローカルは常にグローバルより優先される。実測でも Python バッファでは `Python_jump` に奪われていた。そのため ftplugin より後に走る **LspAttach でバッファローカルとして張り直す**方式にした（`lua/config/keymap/symbol-nav.lua`）。

さらに copilot LSP は全 filetype に attach するが `textDocument/documentSymbol` を持たない。`client:supports_method("textDocument/documentSymbol")` で絞り、シンボルを出せるサーバが付いたバッファにだけマップする。

### キー割り当て

Vim 伝統の割り当てに合わせた。`]]` `[[` は従来 aerial の全シンボル移動だったが、クラス移動に用途を特化。

| キー | 動作 |
| --- | --- |
| `]m` / `[m` | 次 / 前の関数・メソッド |
| `]]` / `[[` | 次 / 前のクラス |
| `<leader>o` | aerial サイドバーのトグル（変更なし） |

### 検証

pyright を attach させた Python fixture（`class` 3 個 / `def` 6 個）で実測。

- シンボル抽出: `Class Shape(1)` `Method area(2)` `Class Circle(6)` `Method __init__(7)` `Method area(10)` `Method scale(13)` `Function helper(17)` `Class Square(21)` `Method area(22)`
- `next_function` を 1 行目から連打: `2 → 7 → 10 → 13 → 17 → 22 → 2`（末尾で先頭へ回り込み）
- `prev_function` を末尾から連打: `22 → 17 → 13 → 10 → 7 → 2 → 22`
- `next_class`: `1 → 6 → 21 → 1` / `prev_class`: `21 → 6 → 1 → 21`
- Python バッファで 4 キーとも `buffer=1` として登録され、ftplugin の `Python_jump` を上書きしていることを確認
- copilot だけが attach する `.txt` では 4 キーとも未マップ＝既定動作のままであることを確認
- カーソルはシンボル名の位置に着地（`selection_range`）、jumplist にも記録される

## Finding 3: 機能重複

### `trouble.nvim`（削除推奨）

5 つのキーマップ全てが既存プラグインでカバーされている。

| trouble | 代替 |
| --- | --- |
| `<leader>xx` diagnostics | `<leader>fd` `snacks.picker.diagnostics` |
| `<leader>xX` buffer diagnostics | `<leader>fD` `snacks.picker.diagnostics_buffer` |
| `<leader>xQ` qflist | `snacks.picker.qflist` |
| `<leader>cs` symbols | `<leader>ss` `snacks.picker.lsp_symbols` / `<leader>o` aerial |
| `<leader>cl` lsp definitions/references | `<leader>gd` `<leader>gr` `<leader>gi` `<leader>gy` snacks |

シンボル一覧に至っては aerial・trouble・snacks の **3 系統**が並立している。

### ターミナル（現状維持を推奨）

`toggleterm.nvim`（`<leader>tt`）と `snacks.terminal` が重複している。`lua/plugin/conform.lua:79` と `lua/plugin/nvim-lint.lua:36` が `snacks_terminal` filetype を除外していることから、snacks 側も使う想定になっている。

ただし toggleterm 側は `lua/plugin/toggleterm.lua:1-81` に pane-tabs 連動のフロート座標計算（エディタペインに重なる位置・サイズを動的算出）を約 80 行持っており、snacks.terminal では容易に再現できない。**残す**判断が妥当。

### `treesj`（優先度低）

キーマップは `<leader>ts` の 1 つのみ。mini 系を既に 4 つ使っているので `mini.splitjoin` に寄せる余地はあるが、削減効果は小さい。

## Finding 4: メンテナンス停止

### `auto-save.nvim`（Pocco81）

アーカイブ済み・未メンテ。加えて `lua/plugin/auto-save.lua:23` の `event = "InsertLeave"` と `lua/plugin/conform.lua:72` の `format_on_save` が組み合わさり、**インサートモードを抜けるたびに保存とフォーマットが走る**。編集途中の不完全なコードが整形される、undo 履歴が分断される、といった副作用が出やすい。

`vim.o.autowriteall` と 10 行程度の autocmd で置換できる。置換時は保存契機を `InsertLeave` から `BufLeave` / `FocusLost` などに変える検討も併せて行う。

## Finding 5: 設定バグ・デッドコード

削除・整理とは独立に修正すべきもの。

| # | 内容 | 該当箇所 |
| --- | --- | --- |
| 1 | **noice の `presets` が `views` の中にネストしている**ため設定全体が無視されている。`opts` の直下に置く必要がある | `lua/plugin/ui.lua:55-60` |
| 2 | treesitter-textobjects のキーマップが旧 API パスを呼び必ず失敗する（Finding 1 参照） | `lua/config/keymap/plugins/treesitter-textobjects.lua:5,9,13,17` |
| 3 | 未使用ローカル変数 `select` / `move` / `swap` | `lua/plugin/treesitter-textobjects.lua:7-9` |
| 4 | blink.cmp の `<Tab>` に `sidekick` 分岐があるが **sidekick.nvim は未インストール**。`pcall` なので無害だがデッドコード。`lua/plugin/lsp.lua:92` の「for Sidekick NES」コメントも古く、実際は Neovim 0.12 の `vim.lsp.inline_completion` を直接使っている | `lua/plugin/blink.lua:38-44` |
| 5 | **`<leader>cb` が衝突**。Comment.nvim の block toggle と AtCoder の build-image。competitive.lua は起動時に `vim.keymap.set` する一方 Comment.nvim は `VeryLazy`（＝後勝ち）なので、**AtCoder の build-image が到達不能**になっている | `lua/plugin/comment.lua:14` / `lua/config/keymap/competitive.lua:83` |
| 6 | **`s` プレフィックスが衝突**。flash.nvim が `s` を n/x/o で取る一方、mini.surround の既定は `sa` `sd` `sr`。`timeoutlen` 待ちが発生する。加えて mini.surround は `InsertEnter` 遅延のため、初回インサート前は surround 側が未マップで `s` が即発火する | `lua/plugin/flash.lua:8` / `lua/plugin/minis.lua:12-16` |
| 7 | `config.keymap.utils` を「モジュール」として require しているが、副作用のない純粋なテーブル返却なので無意味 | `lua/config/keymap/init.lua:3` |
| 8 | `install = { colorscheme = { "kawaii" } }` だが実際の colorscheme 名は `kawaii-theme` | `lua/config/lazy.lua:24` / `lua/plugin/ui.lua:12` |
| 9 | gitsigns は blame 2 つしかマップしておらず、hunk 移動・ステージ・プレビュー（`]c` `<leader>hs` `<leader>hp` 等）が未割当。実質サインカラム表示専用になっている | `lua/config/keymap/plugins/gitsigns.lua` |

## Action Summary

| 区分 | 件数 | 対象 | 状態 |
| --- | --- | --- | --- |
| 削除（争いなし） | 4 | `nvim-web-devicons` `nvim-notify` `lazygit.nvim` `mini.bracketed` | **対応済み** |
| 新規追加 | 1 | 関数・クラスの LSP 移動（`lua/config/symbol-nav.lua`） | **対応済み** |
| 削除（条件付き） | 1 | `Comment.nvim` — ブロックコメントを使わない場合のみ | 未対応 |
| 削除（重複解消） | 1〜2 | `trouble.nvim`、任意で `treesj` | 未対応 |
| 置換 | 1 | `auto-save.nvim` → autocmd | 未対応 |
| 新規追加 | 1 | `nvim-treesitter` の spec＋パーサ導入 | 未対応（Handoff 参照） |
| 新規追加 | 1 | textobjects の select 導入（`vaf` `dif`） | 未対応（Handoff 参照） |
| 設定修正のみ | 9 | Finding 5 の一覧 | 未対応 |

44 → 40（現在）→ 残りを整理して **37〜38 プラグイン**（`nvim-treesitter-textobjects` は残す方針に決定したため）。

## Handoff: treesitter 復活と textobjects 導入

**別セッションで続きをやるための引き継ぎ。ここだけ読めば着手できるように書いてある。**

### 決定事項

`nvim-treesitter-textobjects` は **残す**。`vaf`（関数全体を選択）と `dif`（関数の中身を削除）を使いたいという要件が確定した。

Finding 2.5 で追加した `]m` `[m` `]]` `[[` が置き換えたのは textobjects の **move だけ**。**select は LSP で代替できない**（LSP の documentSymbol は名前付き宣言しか返さないので `@parameter` `@conditional` `@loop` `@call` `@return` を取得できない）。したがって select を使うために treesitter パーサの導入が必要になる。

### 現状（着手前の状態）

| 項目 | 状態 |
| --- | --- |
| treesitter パーサ | **ゼロ**。Neovim 同梱の 7 つ（`c` `lua` `markdown` `markdown_inline` `query` `vim` `vimdoc`）のみ |
| `nvim-treesitter` の spec | **存在しない**。他 4 プラグインの `dependencies` 経由でのみ取得されている |
| `lua/plugin/treesitter-textobjects.lua` | `config` で `select` `move` `swap` を require するが**変数に代入しただけで未使用**（デッドコード） |
| `lua/config/keymap/plugins/treesitter-textobjects.lua` | move の 4 キー（`]f` `[f` `]F` `[F`）のみ。**旧 API パスを呼んでいて必ず失敗する** |
| select / swap のキーマップ | **1 つも無い** |

つまり 4 機能（select / move / swap / repeatable_move）のうち **1 つも動いていない**。

### 実装手順

**1. `lua/plugin/treesitter.lua` を新設**

main ブランチの公開 API は `setup()` `install()` `update()` `get_installed()` `get_available()` `uninstall()` `indentexpr()`（`nvim-treesitter/lua/nvim-treesitter/init.lua` で実測）。**`ensure_installed` は存在しない** — master ブランチの記事をそのまま真似ると動かない。

インストール対象の候補（LSP・conform・nvim-lint が対象にしている言語）:

```
lua python rust typescript tsx javascript json jsonc yaml css html bash markdown toml
```

`nvim-treesitter-textobjects` 側の `textobjects.scm` は上記すべてに存在することを確認済み（79 言語分を同梱）。

**2. `vim.treesitter.start()` を自分で呼ぶ**

**重要**: Neovim 0.12 は treesitter を自動有効化しない。同梱 ftplugin のうち `vim.treesitter.start()` を呼ぶのは **`help.lua` `lua.lua` `markdown.lua` `query.lua` の 4 つだけ**（実測）。Python / Rust / TypeScript などは自分で `FileType` autocmd から呼ぶ必要がある。

**3. select のキーマップを追加**

現行 API は `select_textobject(query, group)`。README の例:

```lua
vim.keymap.set({ "x", "o" }, "am", function()
  require("nvim-treesitter-textobjects.select").select_textobject("@function.outer", "textobjects")
end)
```

`af` / `if` / `ac` / `ic` / `aa` / `ia` は**プラグインの既定ではなく自分で決めるもの**。README 自体は関数に `am` / `im`（m = method）を割り当てている。`vaf` `dif` を使いたいので `af` = `@function.outer`、`if` = `@function.inner` を割り当てる。

使える capture（Python の例、`queries/python/textobjects.scm`）:

```
@function  @class  @parameter  @call  @return  @conditional  @loop
@block  @assignment(.lhs/.rhs)  @comment  @number  @statement
```

**4. ftplugin 衝突は select では起きない（重要）**

同梱 ftplugin が奪うのは `]]` `[[` `][` `[]` `]m` `[m` `]M` `[M` で、しかも **n / o / x の 3 モードすべて**（`ftplugin/python.vim:69-79` で実測）。一方 `af` `if` `ac` `ic` は誰も使っていないので、**select を入れる分には `vim.g.no_plugin_maps` は不要**。

README は冒頭で `vim.g.no_plugin_maps = true` を勧めているが、これは textobjects の **move** を `]m` `]]` に割り当てる前提の話。今回は move を LSP 版（Finding 2.5）に置き換え済みなので設定しないこと。設定すると 29 個の ftplugin のマップが一斉に消える。

**5. move キーマップの後始末**

`]f` `[f` `]F` `[F` は壊れており、かつ `]m` `[m`（Finding 2.5）と役割が重複する。以下のいずれか。

- **推奨**: `lua/config/keymap/plugins/treesitter-textobjects.lua` を削除し、spec の `keys = ...` も外す。ロード契機は select のキーマップ側に持たせる
- 残すなら require パスを `nvim-treesitter-textobjects.move` に直す。ただし `]f` `[f` は ftplugin 衝突こそ無いものの `]m` `[m` と二重になる

**6. `lua/plugin/treesitter-textobjects.lua` のデッドコード削除**

`config` 冒頭の `local select = ...` / `local move = ...` / `local swap = ...` は未使用（Finding 5 #3）。

### 動作確認の手順

パーサが入ったか、select が効くかは以下で確認できる。

```sh
# インストール済みパーサ
nvim --headless -c 'lua print(vim.inspect(require("nvim-treesitter").get_installed()))' +qa

# ランタイムから見えるパーサ（同梱 7 つ + インストール分）
nvim --headless -c 'lua print(table.concat(vim.api.nvim_get_runtime_file("parser/*", true), "\n"))' +qa

# 対象バッファで treesitter highlighter が起動しているか
nvim --headless some.py -c 'lua print(vim.treesitter.highlighter.active[0] ~= nil)' +qa
```

`vaf` / `dif` は headless では検証しにくいので、実際に Python か TypeScript のファイルを開いて手で確認するのが確実。

### この作業で影響を受ける既存の変更

Finding 2.5 で入れた `lua/config/symbol-nav.lua` は **aerial の LSP バックエンド**を見ている。パーサが入ると aerial の `treesitter` バックエンドも動きだすが、`backends = { "lsp", "treesitter", "markdown" }` の優先順で LSP が勝つため挙動は変わらない。LSP が無いバッファでは treesitter にフォールバックして `]m` `]]` が効くようになる（改善方向）。

ただし `lua/config/keymap/symbol-nav.lua` は `LspAttach` でしかマップを張らないので、treesitter だけのバッファでは依然マップされない。そこまで欲しくなったら `FileType` 契機に変える。

## Notes

- 自作プラグイン `uvu1/kawaii-theme.nvim` と `uvu1/pane-tabs.nvim` は整理対象外。
- 適用状況は Progress および Action Summary の「状態」欄を参照。適用済みの項目は該当 Finding にも検証結果を追記している。
- 別セッションで続きをやる場合は「Handoff: treesitter 復活と textobjects 導入」から読むこと。
- 棚卸し時点: Neovim 0.12.4、`lazy-lock.json` は 44 エントリ。
- 最終更新時点: `nvim-web-devicons` `nvim-notify` `lazygit.nvim` `mini.bracketed` の削除により `lazy-lock.json` は 40 エントリ。
