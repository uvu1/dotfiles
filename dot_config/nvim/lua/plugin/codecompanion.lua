return {
  {
    "olimorris/codecompanion.nvim",
    cmd = {
      "CodeCompanionChat",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "saghen/blink.cmp",
    },

    opts = {
      interactions = {
        chat = {
          adapter = {
            name = "copilot",
            model = "gpt-4.1",
          },
        },
      },

      adapters = {
        acp = {
          codex = function()
            return require("codecompanion.adapters").extend("codex", {
              defaults = {
                auth_method = "chatgpt",
                session_config_options = {
                  mode = "Full Access",
                  thought_level = "Xhigh",
                },
              },
            })
          end,
        },
      },

      display = {
        chat = {
          window = {
            layout = "vertical",
            position = "right",
            width = 0.38,
            full_height = true,
            border = "rounded",
            opts = {
              number = false,
              relativenumber = false,
              signcolumn = "no",
              wrap = true,
              linebreak = true,
              winfixwidth = true,
            },
          },
        },

        action_palette = {
          opts = {
            show_preset_prompts = false,
          },
        },
      },
    },
  },
}
