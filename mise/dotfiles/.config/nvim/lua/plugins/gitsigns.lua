return {
  {
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
    config = function()
      require("gitsigns").setup()
    end,
    keys = {
      { "<leader>db", "<cmd>Gitsigns blame<cr>", desc = "Blame file (gitsigns)" },
      { "<leader>dB", "<cmd>Gitsigns blame_line<cr>", desc = "Blame current line (gitsigns)" },
      -- hunk 操作（Finding 9: 従来は未割当だった）
      { "]c", "<cmd>Gitsigns next_hunk<cr>", desc = "Next hunk (gitsigns)" },
      { "[c", "<cmd>Gitsigns prev_hunk<cr>", desc = "Prev hunk (gitsigns)" },
      { "<leader>ds", "<cmd>Gitsigns stage_hunk<cr>", mode = { "n", "x" }, desc = "Stage hunk (gitsigns)" },
      { "<leader>dr", "<cmd>Gitsigns reset_hunk<cr>", mode = { "n", "x" }, desc = "Reset hunk (gitsigns)" },
      { "<leader>dp", "<cmd>Gitsigns preview_hunk<cr>", desc = "Preview hunk (gitsigns)" },
    },
  },
}
