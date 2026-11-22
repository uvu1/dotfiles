# herdr の Claude と Neovim の連携

Claude CLI の起動・会話・再開・モデル選択は herdr のペインで行う。
Neovim は `coder/claudecode.nvim`（コミュニティ製）を `terminal.provider = "none"` で使い、
選択共有と提案 diff の承認・却下だけを担当する。Neovim 内に Claude 端末は作らない。

## 接続

1. ローカルで Neovim を開く。連携サーバーは自動で起動する。
2. 同じプロジェクトの herdr ペインで `claude --ide` を起動する。
   既に Claude を開いている場合は `/ide` から Neovim を選択する。
3. `:ClaudeCodeStatus` で状態を確認する。

複数の Neovim がある場合は接続先を確認する。SSH 先の Neovim ではこの連携を無効化している。
CLI の認証・履歴・連携用 lockfile は端末ローカルで管理し、リポジトリへ追加しない。

## 操作

| キー | 動作 |
| --- | --- |
| `<leader>ab` | 現在のファイルを共有 |
| visual の `<leader>as` | 選択範囲を送信 |
| Explorer の `<leader>as` | ファイルを共有 |
| `<leader>aa` / `<leader>ad` | 提案 diff を承認 / 却下 |

従来の `<leader>ac/af/ar/aC/am` による Neovim 内端末の開閉・フォーカス・再開・モデル選択は廃止。
送信後のペイン切り替えは herdr で行う。適用後の Git 差分の確認は gitsigns / diffview を使う。

## 一次情報

- [使用中のプラグインの none provider](https://github.com/coder/claudecode.nvim/blob/2390c6e45c4789072c293ac69de051d169668b29/README.md#none-no-op-provider)
- [Claude Code CLI](https://code.claude.com/docs/en/cli-reference)
