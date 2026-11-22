-- Claude CLI は herdr で起動し、--ide または /ide で接続する。
-- ローカルでは共有・diff 用サーバーだけを常時起動する。SSH先は environment.spec が無効化。
return {
  {
    "coder/claudecode.nvim",
    lazy = false,
    opts = {
      auto_start = true,
      terminal = { provider = "none" },
    },
    keys = {
      { "<leader>a", nil, desc = "AI/Claude Code" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
      {
        "<leader>as",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file",
        ft = { "snacks_picker_list" },
      },
      -- diff レビュー
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    },
  },
}
