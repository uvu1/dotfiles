# Neovim AI 統合（claudecode.nvim ＋ 実験的 OpenAI プロキシ）

nvim 再構成に伴い、nvim 内の AI を **codecompanion + 自作 pane-tabs** から
**`coder/claudecode.nvim`** へ全面移行した。あわせて「Claude Code を OpenAI モデルで
使う」実験トラック（本体構築とは分離）の方針・リスクをここに記録する。

> 公式 / コミュニティの区別（重要）
> - `ANTHROPIC_BASE_URL` 等の環境変数、Amazon Bedrock / Google Vertex / Microsoft Foundry
>   ゲートウェイは **Anthropic 公式**（[env-vars](https://code.claude.com/docs/en/env-vars.md) /
>   [gateways](https://code.claude.com/docs/en/gateways.md)）。
> - `claudecode.nvim`・`LiteLLM`・`codex-acp` は **すべてコミュニティ（非公式）**。

## 1. claudecode.nvim 構成

- 実体: `lua/plugins/claudecode.lua`。`coder/claudecode.nvim`（コミュニティ・非公式、MIT、要 snacks）。
- 仕組み: Claude Code の公式 IDE プロトコル（loopback WebSocket + MCP、`~/.claude/ide/<port>.lock`）を
  Lua で実装し、nvim を "IDE" 化する。Claude Code CLI は nvim 端末（snacks プロバイダ）で起動。
- 提供機能: エディタ内 diff accept/deny、現在ファイル/選択範囲の context 共有、複数ターミナルプロバイダ。
- 前提: `claude` CLI が PATH 上にあること（mise で管理）。

### キーマップ（`<leader>a*` — pane-tabs が空けた名前空間を流用）

| キー | 動作 |
| --- | --- |
| `<leader>ac` | Toggle Claude（`:ClaudeCode`） |
| `<leader>af` | Focus Claude |
| `<leader>ar` / `<leader>aC` | Resume / Continue |
| `<leader>am` | Select model |
| `<leader>ab` | Add current buffer to context |
| `<leader>as` | Send selection（visual）/ ファイルツリーで file 追加 |
| `<leader>aa` / `<leader>ad` | Diff accept / deny |

### pane 内の操作

- pane は terminal mode 維持（`terminal.auto_insert` 既定 `true`）。クリックしたらそのまま Claude へ入力できる。
- nvim 側の `dd` は terminal buffer が `nomodifiable` なため原理的に使えない。入力欄で `dd` / `cc` /
  text object を使いたい場合は **Claude Code CLI 側の vim mode**（`settings.json` の `editorMode: "vim"`、
  または `/config` → Editor mode。[公式](https://code.claude.com/docs/en/interactive-mode#vim-editor-mode)）
  を有効にする。**現在は未設定（既定の `normal`）** — 一旦切る判断。
- pane 内では、選択を作り得る左ボタン系イベントをすべて無効化している（`<LeftMouse>` のみ残す —
  クリックでのフォーカス移動とカーソル位置決めに必要）。既定レンダラ（`tui: "default"`）は
  [マウスを掴まない](https://code.claude.com/docs/en/fullscreen)ので pane 上のクリックは nvim が処理し
  （`:h terminal-mouse`）、クリックで `t` → `nt` に落ちた直後に nvim が選択を作って visual mode に
  入ってしまうため。`vim.on_key` + `ModeChanged` で実測しながら経路を順に塞いだ:
  `<LeftDrag>` → 確定が `<LeftRelease>` に持ち越し → `<2-LeftMouse>` の単語選択が残存。
  `nt` は Normal の一種（`:h mode()`）なので `mode = { "n", "t" }` で捕まる。
  マウスでのテキスト選択は使えなくなるので、コピーは `<C-\><C-n>` で nvim normal mode に抜けてから行う。
  なお `/tui fullscreen` にすると Claude 側がマウスを掴むため、この細工なしでも visual mode に入らなくなる
  （代わりに会話が alternate screen に入り、nvim 側の scrollback には残らない）。

### diff レビュー運用

- claudecode.nvim の diff は**変更適用前**のプレビュー（`<leader>aa` = `:w` で accept、`<leader>ad` = `:q` で deny）。
- 一方、**適用後**のレビューは従来どおり diffview / gitsigns（git 差分）を使う。役割分担:
  claudecode = 提案 diff の即時 accept/deny、diffview = コミット/作業ツリー全体のレビュー。

## 2. 実験トラック: OpenAI プロキシ（本体構築と分離・任意）

「claudecode.nvim を使いつつ、翻訳プロキシ経由で Claude Code を OpenAI(GPT) モデルで動かす」案。
**nvim 設定リポジトリの再構成には含めない**（動く/動かないに関わらず nvim 本体は完結させる）。
プロキシは shell / mise 環境側の設定。

### 手順（実装時）

1. **翻訳プロキシを mise/uv で導入**: Anthropic Messages API ⇄ OpenAI API を翻訳するもの。
   **LiteLLM（Python, mise/uv 管理）** の Anthropic 互換 `/v1/messages` エンドポイントを第一候補とする。
   `claude-code-router` は `npm i -g` 前提でユーザー方針（nix/mise 管理・グローバル npm 禁止）に反するため不採用。
2. **ローカル起動**し、Claude Code CLI の `ANTHROPIC_BASE_URL`（必要なら `ANTHROPIC_AUTH_TOKEN`）を
   そのプロキシに向ける。claudecode.nvim はバックエンドのモデルに依存しないので、nvim 統合
   （diff / 選択共有）はそのまま効く（設計上の推定）。
3. **全セッションに適用しない**: 専用 alias/ラッパー（例 `claude-gpt`）で、プロキシ経由セッションだけを
   分離する。通常の `claude` は素の Anthropic のまま。
4. **検証**: tool 呼び出し・diff・スラッシュコマンドが実用に耐えるか実機で確認する。

### リスク（明示）

1. **Anthropic 公式が非サポートと明言**:
   [gateways.md](https://code.claude.com/docs/en/gateways.md) —
   "Anthropic doesn't endorse, maintain, or audit other gateway products, and doesn't support
   routing Claude Code to non-Claude models through any gateway."
2. **tool_use ⇄ function_call 翻訳の信頼性**が中〜高リスク（スキーマ差、`tool_use_id` マッピング、
   GPT は Anthropic tool use スキーマを学習していない）。
3. 本質は「**Claude Code のハーネス（/plan 等）で GPT を動かす**」＝ Codex 本体のエージェント挙動ではない。
4. 課金 / 認証 / ToS の扱いは**未確認**（要 Anthropic 確認）。

### Codex を使いたい場合の代替

- 上記プロキシ実験が不調なら、Codex CLI を nvim 端末（`:terminal` / snacks.terminal）で
  単体起動する（スラッシュコマンドはフルに使える）。codecompanion 経由の ACP（`codex-acp`）は今回廃止。
