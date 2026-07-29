return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    -- mini.icons が mock_nvim_web_devicons() で nvim-web-devicons を代替する。
    -- lualine と mini.icons はどちらも VeryLazy なので、mock が先に走るよう依存に置く。
    -- aerial は winbar のパンくずに使う。lualine は setup() 時に
    -- pcall(require, "lualine.components.aerial") で名前解決するため、rtp に
    -- 無いと pcall が失敗して winbar に文字列 "aerial" がそのまま出る。
    dependencies = { "nvim-mini/mini.icons", "stevearc/aerial.nvim" },
    config = function()
      local statusline = require("statusline")
      local sections = statusline.sections()

      statusline.setup()
      vim.opt.laststatus = 2

      require("lualine").setup({
        options = {
          theme = statusline.theme(),
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
        winbar = statusline.winbar(),
        inactive_winbar = {},
      })
    end,
  },
}
