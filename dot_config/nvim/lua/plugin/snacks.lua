return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,

    ---@type snacks.Config
    opts = {
      bigfile = { enabled = true },
      quickfile = { enabled = true },

      dashboard = {
        enabled = true,
        width = 60,
        pane_gap = 4,

        preset = {
          header = [[
███╗   ██╗██╗   ██╗██╗███╗   ███╗
████╗  ██║██║   ██║██║████╗ ████║
██╔██╗ ██║██║   ██║██║██╔████╔██║
██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝
          ]],

          keys = {
            { icon = " ", key = "f", desc = "Find File", action = "<leader>ff" },
            { icon = " ", key = "g", desc = "Grep", action = "<leader>fg" },
            { icon = " ", key = "e", desc = "Explorer", action = "<leader>e" },
            { icon = " ", key = "r", desc = "Recent Files", action = "<leader>fr" },
            { icon = " ", key = "c", desc = "Config", action = "<leader>fc" },
            { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },

        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          {
            icon = " ",
            title = "Recent Files",
            section = "recent_files",
            indent = 2,
            padding = { 1, 1 },
          },
          {
            icon = " ",
            title = "Projects",
            section = "projects",
            indent = 2,
            padding = { 1, 1 },
          },
          { section = "startup" },
        },
      },

      explorer = {
        enabled = true,
        replace_netrw = true,
        trash = true,
      },

      picker = {
        enabled = true,
        ui_select = true,

        sources = {
          explorer = {
            hidden = true,
            ignored = true,
            follow_file = true,
            git_status = true,
            diagnostics = true,
            auto_close = false,

            layout = {
              preset = "sidebar",
              preview = false,
              hidden = { "input" },
              layout = {
                width = 0.18,
              }
            },
          },

          files = {
            hidden = true,
            ignored = false,
          },

          grep = {
            hidden = true,
            ignored = false,
          },
        },
      },

      input = { enabled = true },
      notifier = { enabled = true },
    },
  },
}
