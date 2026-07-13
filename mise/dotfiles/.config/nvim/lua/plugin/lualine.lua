return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local pane = require("config.lualine-pane")
      local sections = pane.sections()

      pane.setup()
      vim.opt.laststatus = 2

      require("lualine").setup({
        options = {
          theme = pane.theme(),
          globalstatus = false,
          always_divide_middle = false,
          component_separators = "",
          section_separators = "",
          refresh = {
            statusline = 250,
            tabline = 1000,
            winbar = 1000,
            refresh_time = 16,
            events = {
              "BufEnter",
              "BufWinEnter",
              "CursorMoved",
              "CursorMovedI",
              "DiagnosticChanged",
              "FileChangedShellPost",
              "FileType",
              "ModeChanged",
              "SessionLoadPost",
              "VimResized",
              "WinClosed",
              "WinEnter",
              "WinNew",
              "WinResized",
            },
          },
        },
        sections = sections,
        inactive_sections = vim.deepcopy(sections),
        tabline = {},
        winbar = {},
        inactive_winbar = {},
      })
    end,
  }
}
