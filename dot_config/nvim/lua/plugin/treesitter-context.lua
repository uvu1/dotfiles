return {
  {
    "nvim-treesitter/nvim-treesitter-context",
    opts = {
      max_lines = 3,
      mode = "cursor",
      separator = nil,
    },
    event = "BufReadPost",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
  }
}
