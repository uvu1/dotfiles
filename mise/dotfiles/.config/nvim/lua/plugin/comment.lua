return {
  {
    "folke/ts-comments.nvim",
    opts = {},
    event = "VeryLazy",
    enabled = vim.fn.has("nvim-0.10.0") == 1,
  },
  {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
    opts = {
      toggler = {
        line = "<leader>cc",
        block = "<leader>cb",
      }
    }
  }
}
