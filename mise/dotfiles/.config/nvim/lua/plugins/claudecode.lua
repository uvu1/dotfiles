-- nvim 内 AI を codecompanion + pane-tabs から claudecode.nvim（コミュニティ・非公式）へ移行。
-- Claude Code CLI を nvim 端末で駆動し、エディタ内 diff accept/deny・選択共有を提供する。
-- pane-tabs が空けた <leader>a* 名前空間を流用（README 推奨のマッピング）。
-- 前提: `claude` CLI が PATH 上にあること。
return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    -- Claude Code の既定レンダラ（tui: "default"）は mouse reporting を有効にしないため、
    -- pane 上のマウスは nvim が処理する（:h terminal-mouse）。フォーカス用のクリックで
    -- t -> nt に落ちた後、nvim が選択を作って visual mode に入ってしまう。
    -- 実測（vim.on_key + ModeChanged）で判明した経路を順に塞いだ結果、選択を作り得る
    -- 左ボタン系イベントすべてが対象。<LeftDrag> だけだと確定が <LeftRelease> に持ち越され、
    -- さらに <2-LeftMouse> の単語選択が残っていた。nt は Normal の一種（:h mode()）なので
    -- "n" で捕まり、"t" は pane 内クリック用。
    -- <LeftMouse> は残す（クリックでのフォーカス移動とカーソル位置決めに必要）。
    opts = function()
      local lhs_list = { "<LeftDrag>", "<LeftRelease>" }
      for _, n in ipairs({ 2, 3, 4 }) do
        for _, ev in ipairs({ "LeftMouse", "LeftDrag", "LeftRelease" }) do
          lhs_list[#lhs_list + 1] = ("<%d-%s>"):format(n, ev)
        end
      end

      local keys = {}
      for _, lhs in ipairs(lhs_list) do
        -- rhs が string だと snacks.win が action 名として解決するので関数を渡す。
        keys["claude_no" .. lhs:gsub("[<>-]", ""):lower()] = {
          lhs,
          function() end,
          mode = { "n", "t" },
          desc = "Disable nvim mouse selection",
        }
      end
      return { terminal = { snacks_win_opts = { keys = keys } } }
    end,
    -- cmd により lazy がコマンドスタブを作り、キー押下前でも :ClaudeCode 系が使える。
    cmd = {
      "ClaudeCode",
      "ClaudeCodeFocus",
      "ClaudeCodeSelectModel",
      "ClaudeCodeAdd",
      "ClaudeCodeSend",
      "ClaudeCodeTreeAdd",
      "ClaudeCodeStatus",
      "ClaudeCodeStart",
      "ClaudeCodeStop",
      "ClaudeCodeOpen",
      "ClaudeCodeClose",
      "ClaudeCodeDiffAccept",
      "ClaudeCodeDiffDeny",
      "ClaudeCodeCloseAllDiffs",
    },
    keys = {
      { "<leader>a", nil, desc = "AI/Claude Code" },
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
      { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
      { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
      { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
      {
        "<leader>as",
        "<cmd>ClaudeCodeTreeAdd<cr>",
        desc = "Add file",
        ft = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw", "snacks_picker_list" },
      },
      -- diff レビュー
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
    },
  },
}
