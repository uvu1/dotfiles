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
      if vim.fn.executable("cargo") == 1 then
        -- ネイティブ実装は任意。ビルド失敗時も補完自体は Lua で利用できる。
        local ok, err = require("blink.cmp").build():pwait(60000)
        if not ok then
          vim.notify("blink.cmp: Lua補完を使います。" .. tostring(err), vim.log.levels.WARN)
        end
      end
    end,

    -- plugin/blink-cmp.lua が LSP capabilities を登録する。LSP 開始前に読む。
    lazy = false,
    priority = 100,

    ---@module "blink.cmp"
    ---@type blink.cmp.Config
    opts = {
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
          "fallback",
        },
        ["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
        ["<C-e>"] = { "hide", "fallback" },
        ["<CR>"] = { "accept", "fallback" },
      },

      completion = {
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
          winblend = 20,
          draw = {
            columns = {
              { "kind_icon" },
              { "label", "label_description", gap = 1 },
              { "source_name" },
            },
          },
        },

        documentation = {
          auto_show = false,
          treesitter_highlighting = false,
          window = {
            winblend = 20,
          },
        },

        ghost_text = {
          enabled = false,
        },
      },

      signature = {
        enabled = true,
        window = {
          winblend = 20,
        },
      },

      sources = {
        default = { "lsp", "path", "snippets", "buffer" },

        providers = {
          lsp = {
            max_items = 80,
            score_offset = 10,
          },
          buffer = {
            score_offset = -5,
          },
        },
      },

      fuzzy = {
        implementation = "prefer_rust",
      },

      cmdline = {
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
