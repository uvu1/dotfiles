return {
  {
    "folke/trouble.nvim",
    opts = {},
    cmd = "Trouble",
    keys = function() return require("config.keymap.plugins.trouble") end,
  }
}
