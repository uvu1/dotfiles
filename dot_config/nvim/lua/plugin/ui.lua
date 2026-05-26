return {
  {
    "uvu1/kawaii-theme.nvim",
    -- dir = vim.fn.expand("~/repo/github.com/uvu/kawaii-theme.nvim"),
    name = "kawaii-theme.nvim",
    lazy = false,
    priority = 1000,
    config = function ()
      require("kawaii-theme").setup({
        transparent = true
      })
      vim.cmd.colorscheme("kawaii-theme")
    end,
  },
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
      cmdline = {
        view = "cmdline_popup",
      },
      views = {
        cmdline_popup = {
          relative = "editor",
          position = {
            row = "25%",
            col = "50%",
          },
          size = {
            width = 70,
            height = "auto",
          },
          border = {
            style = "rounded",
            padding = { 0, 1 },
          },
        },

        cmdline_popupmenu = {
          relative = "editor",
          position = {
            row = "31%",
            col = "50%",
          },
          size = {
            width = 70,
            height = 10,
          },
          border = {
            style = "rounded",
            padding = { 0, 1 },
          },
        },

        presets = {
          bottom_search = false,
          command_palette = false,
          long_message_to_split = false,
          lsp_doc_border = false,
        }
      }
    },
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    }
  }
}
