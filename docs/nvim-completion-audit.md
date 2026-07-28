# Neovim 補完設定の評価

## Summary

- 対象は `mise/dotfiles/.config/nvim` の補完まわり。`blink.cmp`（v2 系, `branch = "main"`）＋ Neovim 0.12 の `vim.lsp.inline_completion`（Copilot LSP）の 2 段構成。
- キーマップ設計（super-tab preset + inline completion フォールバック、`preselect = false`）は一貫していて筋が良い。
- 最大の問題は **blink の LSP capabilities が LSP クライアントに届いていないこと**。遅延ロード契機のせいで、LSP 補完の品質が実質「素の Neovim」相当に落ちている。
- 次に **`<C-c>` の insert モードマッピングが insert 脱出を壊している**。候補が無いとき完全な no-op になる。
- cmdline は `auto_insert = false` の上書きにより、**メニューの選択が見た目だけで `<CR>` が選択を無視する**状態。
- 加えて無効・冗長な設定が 5 件、廃止済みプラグイン向けの死んだ filetype 分岐が 4 ファイル / 5 箇所。

以降、ファイルパスは断りが無い限り `mise/dotfiles/.config/nvim/` からの相対パス。

## Progress

| 項目 | 区分 | 状態 |
| --- | --- | --- |
| Finding 1: blink の LSP capabilities が未適用 | 修正（重大） | 未対応 |
| Finding 2: `<C-c>` が insert 脱出を壊す | 修正（重大） | 未対応 |
| Finding 3: cmdline の選択が挿入されない | 修正 | 未対応 |
| Finding 4: `fuzzy.implementation = "rust"` のハードエラー | 要判断 | 未対応 |
| Finding 5: 無効・冗長な設定 5 件 | 整理 | 未対応 |
| Finding 6: 廃止済み AI プラグインの filetype 分岐 5 箇所 | 整理 | 未対応 |

## Verified Facts

推測ではなく実測した内容。

| 検証項目 | 方法 | 結果 |
| --- | --- | --- |
| Neovim バージョン | `nvim --version` | **0.12.4**（`mise/dotfiles/mise/config.unix.toml:15` で `neovim = "0.12.4"` 固定） |
| blink.cmp の pin | `lazy-lock.json` | `branch = "main"`, commit `0f54bd78892f587db4dcf100a23eaddfc2a9df7d`。`blink.lib` は `5876dd95` |
| 遅延ロード時の LSP capabilities | `nvim --headless "+e lua/config/options.lua"` → attach 待ち → `client.config.capabilities` を印字 | `lua_ls snippetSupport=nil labelDetails=nil resolveSupport=false`。`package.loaded["blink.cmp"]` は `false` |
| blink 先読み時の LSP capabilities | 同上に `require("lazy").load({plugins={"blink.cmp"}})` を先行させる | `lua_ls snippetSupport=true labelDetails=true resolveSupport=true` |
| capabilities の登録箇所 | `blink.cmp/plugin/blink-cmp.lua:1-5` | `vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities(user_caps) })`。**`plugin/` なので lazy ロードまで実行されない** |
| `<C-c>` の実マッピング | `nvim --headless` + `verbose imap <C-c>` | `i <C-C> * <Lua 83: ~/.config/nvim/lua/config/keymaps.lua:12>`。**マップ済み** |
| `vim.lsp.inline_completion.get()` の仕様 | `$VIMRUNTIME/lua/vim/lsp/inline_completion.lua:451-465` | 戻り値は `boolean`。doc の推奨形は `expr = true` + キー返却のフォールバック |
| blink の cmdline 既定 | `blink.cmp/lua/blink/cmp/config/init.lua:47-55` | `list.selection = { preselect = true, auto_insert = true }`, `menu.auto_show = false`, `ghost_text.enabled = true` |
| `auto_insert = false` の効果 | `blink.cmp/lua/blink/cmp/completion/list.lua:200` | `if auto_insert and item ~= nil then list.apply_preview(item) end` → **false だと選択してもバッファ/コマンドラインに反映されない** |
| cmdline の sources | `config/init.lua:48` + `init.lua:57-60` | mode override（`per_mode`）はユーザ opts より優先されるため、cmdline では `{ "buffer", "cmdline" }` が有効。**`sources.default` の上書きで cmdline 補完が壊れているわけではない** |
| blink 既定値との一致 | `config/fuzzy.lua:23-39`, `config/completion/menu.lua:68` | `max_typos = floor(#kw/4)`, `sorts = { "score", "sort_text" }`, `keyword.range = "prefix"`, `draw.treesitter = {}` はすべて既定と同一 |
| `vim.b.completion` の尊重 | `blink.cmp/lua/blink/cmp/init.lua:35-43` | `if vim.b.completion == false then return false end`。**`enabled` 関数と `vim.b.completion` は同じ役割** |
| `signature.enabled` の既定 | `config/signature.lua:31` | `false`。よって `blink.lua:101` の `enabled = true` は意図的な有効化 |
| draw components の妥当性 | `config/completion/menu.lua:78,119,125` | `kind_icon` `label` `label_description` `source_name` すべて実在 |
| keymap command の妥当性 | `config/keymap.lua:174-193` | `show_and_insert_or_accept_single` `select_and_accept` `snippet_forward` `show_documentation` すべて実在 |
| 公式の lazy.nvim 導入例 | `blink.cmp/doc/blink-cmp.txt:121-168` | `dependencies = { "saghen/blink.lib", "rafamadriz/friendly-snippets" }` と `build`。**`event` は指定されていない** |
| noice 検出時の cmdline ghost text | `doc/blink-cmp.txt:3471,3485-3491` | noice.nvim を検出すると ghost text が出るのが既定。本設定は明示的に無効化している |
| rust toolchain | `mise/dotfiles/mise/config.unix.toml:22` | `rust = "1.97.0"`。`blink.cmp/lib/` に `libblink_cmp_fuzzy.dylib.0f54bd7` が存在（ビルド済み） |

## 構成の全体像

| 要素 | 宣言箇所 | 役割 |
| --- | --- | --- |
| `saghen/blink.cmp` | `lua/plugins/blink.lua:3` | メニュー型補完（LSP / path / snippets / buffer）＋ cmdline |
| `saghen/blink.lib` | `lua/plugins/blink.lua:8` | blink v2 の共通ライブラリ（config スキーマ・Task） |
| `rafamadriz/friendly-snippets` | `lua/plugins/blink.lua:9` | snippets ソースの実体 |
| `vim.lsp.inline_completion` | `lua/plugins/lsp.lua:93,101-119` / `lua/config/keymaps.lua:12` | Copilot LSP のインライン（複数行）補完。Neovim 0.12 組み込み |

ソースの優先度は `lsp +10` / `path +3` / `snippets -1` / `buffer -5`（`lua/plugins/blink.lua:110-124`）。

## Finding 1: blink の LSP capabilities が LSP クライアントに届いていない（最優先）

`lua/plugins/blink.lua:16` の `event = { "InsertEnter", "CmdlineEnter" }` が原因。

blink v2 は `plugin/blink-cmp.lua` で `vim.lsp.config("*", { capabilities = ... })` を設定する。lazy.nvim は `plugin/` をプラグインロード時にしか source しないため、**初回 `InsertEnter` まで実行されない**。

一方で LSP 側は先に走る。

- `lua/plugins/lsp.lua:9` — `nvim-lspconfig` は `lazy = false`
- `lua/plugins/lsp.lua:125` — `mason-lspconfig` は `event = { "VeryLazy", "BufReadPre" }` で `automatic_enable = true`

結果、**LSP クライアントは blink より先に `initialize` を投げ、Neovim 既定の capabilities のまま起動する**。capabilities は `initialize` の一度しか送られず、同一 root_dir ではクライアントが再利用されるため、セッション中ずっとこの状態が続く。

実測（Verified Facts 参照）:

| | `snippetSupport` | `labelDetailsSupport` | `resolveSupport` |
| --- | --- | --- | --- |
| 現状（blink 遅延） | `nil` | `nil` | `false` |
| blink 先読み | `true` | `true` | `true` |

### 影響

- **LSP スニペット展開が無効**。関数補完で引数プレースホルダが出ない
- `lua/plugins/blink.lua:80` で描画に使っている **`label_description` が常に空**（`doc/blink-cmp.txt:1311-1313` が capabilities 未設定時の症状として明記している）
- **resolve 経由のドキュメントと `additionalTextEdits`（auto-import）が来ない**

### 対応方針

`event` 行を削除する（公式の lazy.nvim 例には `event` が無い）か、`lazy = false` を明示する。blink は内部で自前に遅延初期化するので、eager ロードでも起動コストはほぼ増えない。

修正後は Verified Facts と同じ手順で `snippetSupport=true labelDetails=true resolveSupport=true` になることを確認する。

## Finding 2: `<C-c>` の insert モードマッピングが insert 脱出を壊している

`lua/config/keymaps.lua:12-16`。

```lua
vim.keymap.set("i", "<C-c>", function()
  if vim.lsp.inline_completion then
    return vim.lsp.inline_completion.get()
  end
end)
```

2 つ問題がある。

1. **`expr = true` が無い**ので `get()` の戻り値（`boolean`）は捨てられる。`$VIMRUNTIME/lua/vim/lsp/inline_completion.lua:451-465` の doc が示す推奨形は `expr = true` + キー返却のフォールバック
2. **フォールバックが無い**ので、候補が無いときこのマッピングは完全な no-op になる。`<C-c>` は本来 insert モードを抜けるキーなので、**候補が出ていない間は insert から抜けられない**

実測で `imap <C-c>` が `keymaps.lua:12` にマップ済みであることを確認している。

さらに `lua/plugins/blink.lua:38-43` の `<Tab>` チェーンに既に inline completion が入っており、**役割が重複している**。

### 対応方針

- insert モードで未使用のキー（`<C-l>` など。`lua/config/keymaps.lua:6-9` の `<C-h/j/k/l>` は `{ "n", "t" }` のみ）へ移す
- もしくは `expr = true` にして、候補が無いときは `"<C-c>"` を返す

## Finding 3: cmdline は選択しても挿入されず `<CR>` が選択を無視する

`lua/plugins/blink.lua:155-160` が cmdline の `preselect` / `auto_insert` を `false` に上書きしている。blink の cmdline 既定は**両方 `true`**（`config/init.lua:51`）。

`completion/list.lua:200` が `if auto_insert and item ~= nil then list.apply_preview(item) end` なので、`auto_insert = false` では選択してもコマンドラインの文字列は変わらない。

その結果:

- `lua/plugins/blink.lua:147` の `<Tab>` = `show_and_insert_or_accept_single` の **"insert" が死ぬ**
- `lua/plugins/blink.lua:162` で `ghost_text.enabled = false` なので**プレビューも出ない**（noice 検出時は blink 既定で有効）
- `lua/plugins/blink.lua:146` の `<CR>` = `fallback` なので、**Enter は選択項目ではなく「打った文字列」をそのまま実行する**

つまりメニューの選択が純粋に見た目だけになり、組み込み wildmenu（Tab で挿入される）とも挙動が食い違う。

### 対応方針

いずれか。

- cmdline の `list.selection` 上書きを外して既定（`preselect`/`auto_insert` = `true`）に戻す。組み込み wildmenu と同じ「Tab で挿入」になる
- `cmdline.completion.ghost_text.enabled = true` に戻して、少なくとも確定内容が見えるようにする

## Finding 4: `fuzzy.implementation = "rust"` はハードエラー

`lua/plugins/blink.lua:128`。ネイティブライブラリが無い場合、`blink.cmp/lua/blink/cmp/init.lua:79-83` が `error()` を投げる（`prefer_rust_with_warning` なら警告して Lua 実装へフォールバックする）。

`lua/plugins/blink.lua:12-14` の `build` は `cargo build --release` を実行するため Rust toolchain が必要で、`mise/dotfiles/mise/config.unix.toml:22` の `rust = "1.97.0"` に依存している。現行マシンではビルド済み（`blink.cmp/lib/` に dylib あり）だが、**新規マシンで nvim のプラグイン同期が `mise install` より先に走ると、以後 `InsertEnter` ごとに例外が出る**。

なお `build():wait(60000)` は公式例の `pwait()` と違い失敗を隠さないので、`implementation = "rust"` と組み合わせる限りむしろ適切。

### 対応方針

堅くするなら以下のいずれか。優先度は低い。

- `implementation = "prefer_rust_with_warning"` にする
- `build()` の代わりに `require("blink.cmp").download()`（プリビルド取得、`init.lua:121`）を使い cargo 依存を外す

## Finding 5: 無効・冗長な設定

| # | 内容 | 該当箇所 |
| --- | --- | --- |
| 1 | `auto_show_delay_ms = 500` が無意味。同じブロックの `auto_show = false` でドキュメントは自動表示されない | `lua/plugins/blink.lua:87-88` |
| 2 | `draw.treesitter = {}` は空リスト＝既定と同じで treesitter ハイライト無効。効かせたいなら `{ "lsp" }` | `lua/plugins/blink.lua:77` |
| 3 | `completion.keyword.range = "prefix"` は blink 既定と同一 | `lua/plugins/blink.lua:58` |
| 4 | `fuzzy.max_typos` と `fuzzy.sorts` は blink 既定と完全一致（`config/fuzzy.lua:27-34`）。`frecency.enabled` と `use_proximity` も既定 `true` | `lua/plugins/blink.lua:129-139` |
| 5 | `enabled` 関数と `lua/plugins/lsp.lua:99` の `vim.b.completion = false` が同じ役割。blink は `vim.b.completion == false` を尊重する（`init.lua:38`）ので片方で足りる | `lua/plugins/blink.lua:21-23` |

## Finding 6: 廃止済み AI プラグインの filetype 分岐

nvim 内 AI は `codecompanion` + `pane-tabs` から claudecode.nvim へ移行済み（`lua/plugins/claudecode.lua:1-3`、`lua/plugins/toggleterm.lua:2` の「pane-tabs を廃止した」コメント）。`lazy-lock.json`（35 エントリ）に `codecompanion.nvim` も `pane-tabs.nvim` も存在しない。

したがって `codecompanion` / `pane-tabs-ai` の**どちらの filetype も発生せず**、以下 4 ファイル / 5 箇所の分岐は全て死んでいる。

| 該当箇所 | 内容 |
| --- | --- |
| `lua/plugins/blink.lua:22` | `enabled` の除外リスト（両方） |
| `lua/plugins/lsp.lua:15-16` | `ai_filetypes` テーブル（両方） |
| `lua/plugins/lsp.lua:97` | FileType autocmd の `pattern`（両方） |
| `lua/plugins/conform.lua:77-78` | フォーマット除外（両方） |
| `lua/plugins/nvim-lint.lua:34-35` | lint 除外（両方） |

`lua/plugins/lsp.lua:95-105` の FileType autocmd は pattern が一致しないため一度も発火しない。同ファイル `116` 行の `ai_filetypes[...]` 参照も常に `nil` なので、実質 `inline_completion.enable(true, ...)` として動いている（意図どおりの結果になっているだけ）。

claudecode.nvim 側のターミナル filetype（`snacks_terminal` 等）を除外したいなら、そちらに書き換える必要がある。

## 良い点

評価上、意図的で妥当と判断した設計。

- **`<Tab>` チェーンが super-tab preset の正しい拡張**（`lua/plugins/blink.lua:28-46`）。preset 本体（`blink.cmp/lua/blink/cmp/keymap/presets.lua:49-58`）の `snippet accept → snippet_forward → fallback` の間に inline completion を差し込んでおり、順序も妥当
- **`preselect = false` / `auto_insert = false` + `<CR> = { "accept", "fallback" }` は安全な組み合わせ**。明示選択が無ければ Enter は素通しで改行になる（insert モードのみ。cmdline は Finding 3）
- **blink 側 `ghost_text = false`** は Copilot の inline overlay と二重表示になるのを避けており妥当。`vim.lsp.inline_completion` は独自の virtual text で描画するため衝突しない
- **`blink.lib` を `dependencies` に入れているのは v2 の公式手順どおり**
- **`signature.enabled = true`** は既定 `false` からの意図的な有効化。トグルの `<C-k>` は preset 由来で、`lua/config/keymaps.lua:9` の `<C-k>` は `{ "n", "t" }` のみなので衝突しない
- **score_offset の設計**（lsp +10 / path +3 / snippets -1 / buffer -5）は素直

## 補足（好みの範囲）

- `mini.icons` が入っているが blink は自動連携しないため、補完メニューだけ blink 内蔵アイコンセットになっている。統一したいなら `doc/blink-cmp.txt:692-724` の mini.icons レシピを使う
- `<C-e>` を preset の `cancel` から `hide` に変えている（`lua/plugins/blink.lua:48`）。`auto_insert = false` では undo すべきプレビューが無いので実質同等

## Action Summary

| 区分 | 件数 | 対象 | 状態 |
| --- | --- | --- | --- |
| 修正（重大） | 2 | Finding 1（capabilities）、Finding 2（`<C-c>`） | 未対応 |
| 修正 | 1 | Finding 3（cmdline の `auto_insert`） | 未対応 |
| 要判断 | 1 | Finding 4（`implementation = "rust"`） | 未対応 |
| 整理 | 5 | Finding 5 の無効・冗長設定 | 未対応 |
| 整理 | 5 | Finding 6 の廃止済み AI filetype 分岐（4 ファイル） | 未対応 |

着手順は Finding 1 → 2 が効果が大きい。

## Notes

- 評価時点: Neovim 0.12.4、`blink.cmp` は `0f54bd78`（`branch = "main"`）、`lazy-lock.json` は 35 エントリ。
- 検証は `~/.local/share/nvim/lazy/blink.cmp` のソース、`$VIMRUNTIME` のランタイム、および headless 実行での capabilities 実測で行った。Web 上の記事は参照していない。
- プラグイン構成全体の棚卸しは `docs/nvim-plugin-audit.md`（ただしパスは再構成前の `lua/plugin/` 表記）、再構成の記録は `docs/nvim-rebuild.md`、AI 連携は `docs/nvim-ai-integration.md`。
