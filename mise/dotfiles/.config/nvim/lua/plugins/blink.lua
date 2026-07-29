return {
  {
    "saghen/blink.cmp",
    branch = "main",
    version = false,

    dependencies = {
      "saghen/blink.lib",
      "rafamadriz/friendly-snippets",
    },

    build = function()
      require("blink.cmp").build():wait(60000)
    end,

    event = { "InsertEnter", "CmdlineEnter" },

    ---@module "blink.cmp"
    ---@type blink.cmp.Config
    opts = {
      enabled = function()
        return not vim.tbl_contains({ "codecompanion", "pane-tabs-ai" }, vim.bo.filetype)
      end,

      keymap = {
        preset = "super-tab",

        ["<Tab>"] = {
          function(cmp)
            if cmp.snippet_active() then
              return cmp.accept()
            end
            return cmp.select_and_accept()
          end,

          "snippet_forward",

          function()
            if vim.lsp.inline_completion then
              return vim.lsp.inline_completion.get()
            end
            return false
          end,

          "fallback",
        },
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
      },

      snippets = {
        preset = "default",
      },

      completion = {
        keyword = {
          range = "prefix",
        },

        list = {
          selection = {
            preselect = false,
            auto_insert = false,
          },
        },

        accept = {
          auto_brackets = {
            enabled = true,
          },
        },

        -- border は書かない。blink の pick_border() が nil のとき winborder を読む
        -- （lib/window/utils.lua）。枠の指定は config/options.lua に集約している。
        menu = {
          draw = {
            treesitter = {},
            columns = {
              { "kind_icon" },
              { "label", "label_description", gap = 1 },
              { "source_name" },
            },
          },
        },

        documentation = {
          auto_show = false,
          auto_show_delay_ms = 500,
          treesitter_highlighting = false,
        },

        ghost_text = {
          enabled = false,
        },
      },

      signature = {
        enabled = true,
      },

      sources = {
        default = { "lsp", "path", "snippets", "buffer" },

        providers = {
          lsp = {
            max_items = 80,
            score_offset = 10,
          },
          path = {
            score_offset = 3,
          },
          snippets = {
            score_offset = -1,
          },
          buffer = {
            score_offset = -5,
          },
        },
      },

      fuzzy = {
        implementation = "rust",
        max_typos = function(keyword)
          return math.floor(#keyword / 4)
        end,
        frecency = {
          enabled = true,
        },
        use_proximity = true,
        sorts = {
          "score",
          "sort_text",
        },
      },

      cmdline = {
        enabled = true,
        keymap = {
          preset = "cmdline",
          ["<CR>"] = { "fallback" },
          ["<Tab>"] = { "show_and_insert_or_accept_single", "select_next" },
          ["<C-y>"] = { "select_and_accept", "fallback" },
          ["<C-e>"] = { "cancel", "fallback" },
        },
        completion = {
          menu = {
            auto_show = false,
          },
          list = {
            selection = {
              preselect = false,
              auto_insert = false,
            },
          },
          ghost_text = {
            enabled = false,
          },
        },
      },
    },
  },
}
