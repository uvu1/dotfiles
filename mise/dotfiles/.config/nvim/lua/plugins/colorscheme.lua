return {
  {
    "uvu1/kawaii-theme.nvim",
    name = "kawaii-theme.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("kawaii-theme").setup({
        transparent = true,
      })
      vim.cmd.colorscheme("kawaii-theme")
    end,
  },
}
