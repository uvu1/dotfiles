# Neovim 設定 ゼロ再構築の記録

`docs/nvim-plugin-audit.md`（棚卸し）を土台に、nvim 設定を空の init.lua から設計し直した記録。
煩雑さの解消（keymap の 3 パターン混在、自作 statusline の肥大、過剰抽象、treesitter 機能停止）が目的。

## 新アーキテクチャ

```
lua/
├── config/        エディタ本体の設定
│   ├── options.lua        （旧 option.lua）
│   ├── lazy.lua           bootstrap + setup({ spec = { { import = "plugins" } } })
│   ├── keymaps.lua        全域キー（旧 base.lua）+ require("config.keymaps.contest")
│   ├── keymaps/contest.lua （旧 competitive.lua）
│   └── autocmds.lua       vimenter / symbol-nav(LspAttach) / auto-save 置換
├── lib/           プラグイン非依存の純ロジック
│   ├── symbol-nav.lua     aerial 走査による関数/クラス移動（旧 config/symbol-nav.lua）
│   └── git-log.lua        git log -L → Diffview（旧 config/git-log.lua）
├── statusline/    自作ステータスライン（旧 config/lualine_pane/ を再設計）
└── plugins/       lazy spec（1 プラグイン 1 ファイル、keys/opts を co-locate）
```

- **keymap の一本化**: 旧構成は「起動時 direct require」「lazy spec の外部ファイル keys + 自作 DSL」
  「spec inline keys」の 3 系統が混在していた。外部 keymap 層（`config/keymap/plugins/*`）と自作 DSL
  （`config/keymap/utils.lua` の `lazyset`/`normalize_rhs`）を全廃し、**プラグインを起動させるキーは
  各 spec の inline `keys=` に、全域キーは `config/keymaps.lua` に**、の 2 分類へ収束。
- 過剰抽象（1〜2 要素のループローダ、無意味な module require）を排除。
- インデントは Spaces / 2 に統一（`stylua.toml` を新設）。

## キーマップ方針: 「極力変更しない」

既存キーは lhs/rhs/mode/desc を **1:1 で移設**した。変更は不可避なもの（プラグイン削除・破損・衝突）のみ。

### 維持した設定（特記）

- **競技プログラミング（AtCoder）**: `<leader>ct/cd/cr/cu/cb/cn/co` を据え置き（`config/keymaps/contest.lua`）。
  `mise run test / test-debug / run / submit / build-image / new` と `oj/acc` を専用 botright 端末で実行。
  **据え置けた理由**: Comment.nvim 削除で `<leader>cb`（旧 block コメントとの衝突, Finding 5#5）が
  解消し、build-image が復活したため改番不要になった。
- flash `s S r R <C-s>`、ufo `zR zM zp`、symbol-nav `]m [m ]] [[`、mini.surround `sa/sd/sr`、
  treesj 置換後の mini.splitjoin `<leader>ts`、explorer/find/symbol の snacks キー群 — すべて不変。
- 流用した自作ロジック: `lib/symbol-nav`（LSP 関数/クラス移動）、`lib/git-log`、
  overseer の `lua/overseer/template/user/just.lua`、自作テーマ `kawaii-theme`。

### 変更したキー（不可避のみ）

| 種別 | 内容 | 理由 |
| --- | --- | --- |
| 削除 | trouble `<leader>xx xX xQ cs cl` | trouble 削除（機能は snacks/aerial で代替済み） |
| 削除 | textobjects move `]f [f ]F [F` | 旧 API で元から破損 |
| 置換 | Comment.nvim `<leader>cc/cb` → 組込 `gcc`/`gc` | Comment.nvim 削除、block 不使用 |
| 追加 | textobjects select `af if ac ic aa ia`（`vaf`/`dif`） | 新規（未使用キー、ftplugin 非衝突） |
| 追加 | gitsigns hunk `]c [c` / `<leader>ds dr dp` | 新規（Finding 9） |
| 削除→再割当 | pane-tabs `<leader>a1/a2/a3/aa/aq/al/as`・`<M-[>`/`<M-]>` | claudecode.nvim の `<leader>a*` へ再割当。`<M-[>`/`<M-]>`（旧バッファ循環）は廃止 |
| desc 修正 | ufo `zR`/`zM`、window nav `<C-j>`/`<C-k>` の説明取り違え | キーは不変、desc のみ訂正 |

## 削除 / 置換したプラグイン

- **trouble.nvim** 削除（重複）/ **auto-save.nvim** → `autowriteall` + `BufLeave`/`FocusLost` autocmd
  （InsertLeave 連発フォーマットの解消）/ **treesj** → `mini.splitjoin` / **Comment.nvim** → 組込 gcc
- **codecompanion + pane-tabs → claudecode.nvim**（詳細は `docs/nvim-ai-integration.md`）。
  これに伴い自作 statusline の `ai.lua`(713 行) と weather(死にコード) を撤去し、statusline は約 -900 行。
- 過去に削除済み（監査）: nvim-web-devicons / nvim-notify / lazygit.nvim / mini.bracketed。

## treesitter 復活

- `lua/plugins/treesitter.lua` を新設（`branch = "main"`, `lazy = false`）。
  `require("nvim-treesitter").install({...})` で 14 言語のパーサを導入（main に `ensure_installed` は無い）。
- Neovim 0.12 は treesitter を自動有効化しないため、`FileType` autocmd で `vim.treesitter.start()` を呼ぶ。
- textobjects は **select のみ**導入（move は LSP 版 `]m/[m` に一本化）。`vim.g.no_plugin_maps` は設定しない。
- 副次的に treesitter-context / rainbow-delimiters / ufo(treesitter provider) / flash `S`/`R` /
  aerial の treesitter バックエンドが同時復活。

## 検証・切り戻し

- 基点タグ: `git tag nvim-rebuild-base`（= 再構成前 HEAD）。切り戻しは
  `git checkout nvim-rebuild-base -- mise/dotfiles/.config/nvim`。
- 起動系の検証: `nvim --headless "+Lazy! sync" +qa` /
  `nvim --headless -c 'lua print(vim.inspect(require("nvim-treesitter").get_installed()))' +qa` /
  `:checkhealth lazy` / `:messages`。
- `vaf`/`dif`・statusline の見た目・補完・claudecode の diff は実機で手動確認。
