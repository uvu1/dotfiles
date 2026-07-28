return {
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {
      cmdline = {
        view = "cmdline_popup",
      },
      -- presets は opts 直下に置く。以前は views の中にネストしていて無視されていた。
      presets = {
        bottom_search = false,
        command_palette = false,
        long_message_to_split = false,
        lsp_doc_border = false,
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
      },
    },
    -- noice の notify view は backend = { "snacks", "notify" } で snacks を優先する
    -- （noice/config/views.lua）。snacks.notifier が有効なので nvim-notify は不要。
    dependencies = {
      "MunifTanjim/nui.nvim",
      "folke/snacks.nvim",
    },
  },
}
