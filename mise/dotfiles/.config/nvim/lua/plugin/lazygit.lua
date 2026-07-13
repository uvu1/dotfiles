return {
  "kdheepak/lazygit.nvim",
  opts = {},
  keys = function() return require("config.keymap.plugins.lazygit") end,
  dependencies = { "nvim-lua/plenary.nvim" },
  cmd = {
    "LazyGit",
    "LazyGitConfig",
    "LazyGitCurrentFile",
    "LazyGitFilterCurrentFile",
    "LazyGitFilter",
  },
}
