return {
  {
    "uvu1/kawaii-theme.nvim",
    name = "kawaii-theme.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "kawaii-theme",
        callback = function()
          local palette = require("kawaii-theme.palette")
          vim.api.nvim_set_hl(0, "NormalFloat", { fg = palette.fg, bg = palette.bg_float })
          vim.api.nvim_set_hl(0, "FloatBorder", { fg = palette.pink2, bg = palette.bg_float })
          vim.api.nvim_set_hl(0, "Pmenu", { fg = palette.fg, bg = palette.bg_dark })
          vim.api.nvim_set_hl(0, "PmenuKind", { fg = palette.purple, bg = palette.bg_dark })
          vim.api.nvim_set_hl(0, "PmenuExtra", { fg = palette.muted, bg = palette.bg_dark })
          vim.api.nvim_set_hl(0, "LspInlayHint", { fg = palette.muted })
          vim.api.nvim_set_hl(0, "LspCodeLens", { fg = palette.muted })
        end,
      })

      require("kawaii-theme").setup({
        transparent = true,
      })
      vim.cmd.colorscheme("kawaii-theme")
    end,
  },
}
