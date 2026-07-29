return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer local Keymaps(which-key)",
    },
  },
  opts = {
    spec = {
      { "<leader>f", group = "Find" },
      { "<leader>g", group = "Goto/LSP" },
      { "<leader>s", group = "Symbols" },
      { "<leader>d", group = "Git/Diff" },
      { "<leader>c", group = "Code/Contest" },
      { "<leader>t", group = "Terminal" },
      { "<leader>r", group = "Run" },
      { "<leader>a", group = "AI" },
      { "<leader>u", group = "UI" },
    },
  },
}
