return {
  {
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
    keys = function() return require("config.keymap.plugins.gitsigns") end,
    config = function()
      require("gitsigns").setup()
    end,
  }
}
