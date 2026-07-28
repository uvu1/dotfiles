return {
  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
      "DiffviewFileHistory",
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        merge_tool = {
          layout = "diff3_mixed",
          disable_diagnostics = true,
        },
      },
    },
    keys = {
      { "<leader>dd", "<cmd>DiffviewOpen<cr>", desc = "Diff working tree (Diffview)" },
      { "<leader>dm", "<cmd>DiffviewOpen origin/HEAD...HEAD<cr>", desc = "Diff against merge base (Diffview)" },
      { "<leader>dh", "<cmd>DiffviewFileHistory<cr>", desc = "Repository history (Diffview)" },
      { "<leader>df", "<cmd>DiffviewFileHistory %<cr>", desc = "Current file history (Diffview)" },
      { "<leader>dt", "<cmd>DiffviewToggleFiles<cr>", desc = "Toggle file panel (Diffview)" },
      { "<leader>dq", "<cmd>DiffviewClose<cr>", desc = "Close Diffview" },
    },
  },
}
