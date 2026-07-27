# Neovim プラグイン棚卸し

## Summary

- 対象は `mise/dotfiles/.config/nvim`。lazy.nvim 管理で現在 **44 プラグイン**（`lazy.nvim` 自身を含む）。
- 最大の問題は **treesitter 系が丸ごと機能していない**こと。`nvim-treesitter` にトップレベル spec が無く、パーサが 1 つもインストールされていない。依存する 4 プラグインが実作業言語で全滅している。
- 明確に不要なもの（Neovim の組み込み機能・snacks.nvim 内蔵機能と重複）が **4 件**、条件付きで不要なものが **1 件**（`Comment.nvim`）。
- 機能重複でどれか一つに寄せるべきものが **1〜2 件**。
- メンテナンス停止プラグインが **1 件**。
- 削除とは別に、設定バグ・デッドコードが **9 件**。
- 整理後の想定は 44 → **36〜37 プラグイン**。

以降、ファイルパスは断りが無い限り `mise/dotfiles/.config/nvim/` からの相対パス。

## Verified Facts

推測ではなく実測した内容。

| 検証項目 | 方法 | 結果 |
| --- | --- | --- |
| Neovim バージョン | `nvim --version` | **0.12.4**（`mise/mise.toml:13` が `neovim = "latest"`） |
| インストール済み treesitter パーサ | `nvim --headless -c 'lua ... vim.api.nvim_get_runtime_file("parser/*", true)'` | **Neovim 同梱の 7 つのみ**（`c` `lua` `markdown` `markdown_inline` `query` `vim` `vimdoc`）。`~/.local/share/nvim/lazy/nvim-treesitter/parser` と `~/.local/share/nvim/site/parser` はいずれも不在 |
| textobjects の API パス | `ls ~/.local/share/nvim/lazy/nvim-treesitter-textobjects/lua/` | `nvim-treesitter-textobjects/` のみ存在。**`nvim-treesitter/textobjects/` は存在しない** |
| snacks.nvim の内蔵モジュール | `ls ~/.local/share/nvim/lazy/snacks.nvim/lua/snacks/` | `lazygit.lua` `terminal.lua` `notifier.lua` `picker/` `explorer/` を確認 |
| 実際にインストール済みのプラグイン | `ls ~/.local/share/nvim/lazy/` | `lazy-lock.json` の 44 件と一致 |

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
| `rcarriga/nvim-notify` | `lua/plugin/ui.lua:65` | noice 依存 | — | **削除** |
| `nvim-lualine/lualine.nvim` | `lua/plugin/lualine.lua:3` | `VeryLazy` | — | 維持 |
| `nvim-tree/nvim-web-devicons` | `lua/plugin/lualine.lua:5` | lualine 依存 | — | **削除** |
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
| `stevearc/aerial.nvim` | `lua/plugin/aerial.lua:3` | keys | `<leader>o` `]]` `[[` | 維持 |

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
| `nvim-treesitter/nvim-treesitter-textobjects` | `lua/plugin/treesitter-textobjects.lua:3` | keys | `]f` `[f` `]F` `[F` | **要修正（キーマップ破損）** |
| `HiPhish/rainbow-delimiters.nvim` | `lua/plugin/rainbow-delimiters.lua:3` | `BufReadPost` `BufNewFile` | — | 維持（要パーサ） |

### 編集

| プラグイン | 宣言箇所 | ロード契機 | キーマップ | 判定 |
| --- | --- | --- | --- | --- |
| `nvim-mini/mini.pairs` | `lua/plugin/minis.lua:3` | `InsertEnter` | `<CR>` (i) | 維持 |
| `nvim-mini/mini.surround` | `lua/plugin/minis.lua:13` | `InsertEnter` | `sa` `sd` `sr` 他（既定） | 要修正（`s` 衝突） |
| `nvim-mini/mini.bracketed` | `lua/plugin/minis.lua:26` | `VeryLazy` | `]d` `[d` `]q` `[q` のみ | **削除** |
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
| `kdheepak/lazygit.nvim` | `lua/plugin/lazygit.lua:2` | cmd / keys | `<leader>tl` | **削除** |
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

加えて、**パーサを入れても `nvim-treesitter-textobjects` のキーマップは動かない**。`lua/config/keymap/plugins/treesitter-textobjects.lua:5,9,13,17` が旧 API の `require("nvim-treesitter.textobjects.move")` を呼んでいるが、main ブランチの実体は `nvim-treesitter-textobjects.move`（Verified Facts で実測）。`]f` `[f` `]F` `[F` は module not found で必ず失敗する。

### 対応方針

`lua/plugin/treesitter.lua` を新設し、main ブランチ向けに以下を書く。

1. `nvim-treesitter` をトップレベル spec として `branch = "main"` で宣言する
2. 使用言語のパーサを `require("nvim-treesitter").install(...)` でインストールする
3. `FileType` autocmd で `vim.treesitter.start()` を呼ぶ

併せて `lua/config/keymap/plugins/treesitter-textobjects.lua` の require パスを `nvim-treesitter-textobjects.move` に修正する。

## Finding 2: 明確に不要なプラグイン

### 1. `mini.bracketed`

`lua/plugin/minis.lua:26-47` で `buffer` `comment` `conflict` `indent` `jump` `location` `oldfile` `treesitter` `undo` `window` `yank` の suffix を全て空文字で無効化している。生きているのは `diagnostic`（`]d` / `[d`）と `quickfix`（`]q` / `[q`）の 2 つだけ。

**この 2 つは Neovim が組み込みで提供している**。`:h default-mappings`（0.12.4）に `]d` `[d` `]D` `[D` と `[q` `]q` `[Q` `]Q` が明記されている（0.11 で追加）。加えて `[b` `]b`（buffer）`[l` `]l`（location list）`[t` `]t`（tag）`[a` `]a`（arglist）`[<Space>` `]<Space>`（空行挿入）も組み込み済みで、これらは元々この設定で無効化されている。

残存価値はゼロ。

### 2. `nvim-web-devicons`

`lua/plugin/lualine.lua:5` で lualine の `dependencies` として読まれている。一方 `lua/plugin/minis.lua:17-24` の `mini.icons` が `MiniIcons.mock_nvim_web_devicons()` を実行しており、アイコン提供が二重になっている。

`dependencies` を `nvim-mini/mini.icons` に差し替えれば `nvim-web-devicons` は不要。差し替えることで mock が lualine より先に走ることも保証される。

### 3. `nvim-notify`

`lua/plugin/ui.lua:65` で noice の `dependencies`。一方 `lua/plugin/snacks.lua:105` で `notifier = { enabled = true }`。通知バックエンドが二重に存在する。

noice の `notify` view を snacks 側に向けるか、noice の通知ルーティングを切って `nvim-notify` を落とす。

### 4. `Comment.nvim`（**条件付き** — ブロックコメントを使うなら残す）

`lua/plugin/comment.lua:8-17`。**Neovim 0.10 以降が `gc` / `gcc` を組み込みで持つ**。さらに併存している `ts-comments.nvim`（`lua/plugin/comment.lua:3`）は、まさに**その組み込みコメント機能**の `commentstring` を treesitter 対応させるためのプラグイン。つまりライン コメントに関してはエンジンが二重になっている。

ただし **Neovim 組み込みにブロックコメントは無い**。`:h default-mappings`（0.12.4）の一覧は `gc` `gcc` `v_gc` `o_gc` のみで `gb` 系は存在せず、`commentstring` ベースのライン コメントだけを扱う。現在の設定は `toggler.block = "<leader>cb"` でブロックコメントを割り当てているため、**Comment.nvim を削除するとこの機能は失われる**。

判断は以下。

- ブロックコメントを使っていない → 削除可。`<leader>cc` を組み込みの `gcc` に割り当て直す
- 使っている → **残す**。ただし `ts-comments.nvim` との役割重複は残るので、どちらか一方に寄せる検討はする

副次的な効果として、Comment.nvim を削除すると Finding 5 #5 の衝突が解消し、AtCoder の `<leader>cb`（build-image）が復活する。

### 5. `lazygit.nvim`

`snacks.nvim` が `Snacks.lazygit` を内蔵している（`snacks/lazygit.lua` を実測で確認）。フロート表示・カラースキーム連携・カレントファイル指定まで同等の機能を持つ。

`lua/config/keymap/plugins/lazygit.lua` の `<leader>tl` を `Snacks.lazygit.open()` に置き換えれば `lua/plugin/lazygit.lua` ごと削除できる。なお `plenary.nvim` は codecompanion が引き続き必要とするため残る。

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

| 区分 | 件数 | 対象 |
| --- | --- | --- |
| 削除（争いなし） | 4 | `mini.bracketed` `nvim-web-devicons` `nvim-notify` `lazygit.nvim` |
| 削除（条件付き） | 1 | `Comment.nvim` — ブロックコメントを使わない場合のみ |
| 削除（重複解消） | 1〜2 | `trouble.nvim`、任意で `treesj` |
| 置換 | 1 | `auto-save.nvim` → autocmd |
| 新規追加 | 1 | `nvim-treesitter` のトップレベル spec |
| 設定修正のみ | 9 | Finding 5 の一覧 |

44 → **36〜37 プラグイン**。

## Notes

- 自作プラグイン `uvu1/kawaii-theme.nvim` と `uvu1/pane-tabs.nvim` は整理対象外。
- 本文書は棚卸し結果のみで、設定ファイルへの変更は一切含まない。
- 検証時点: Neovim 0.12.4、`lazy-lock.json` は 44 エントリ。
