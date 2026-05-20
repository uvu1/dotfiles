local function executable(path)
  return type(path) == "string" and path ~= "" and vim.fn.executable(path) == 1
end

local function codex_acp_command()
  local from_path = vim.fn.exepath("codex-acp")

  if executable(from_path) then
    return { from_path }
  end

  local candidates = vim.fn.glob(vim.fn.expand("~/.local/share/mise/installs/node/*/bin/codex-acp"), false, true)

  table.sort(candidates, function(a, b)
    return a > b
  end)

  vim.list_extend(candidates, {
    vim.fn.expand("~/.local/share/mise/shims/codex-acp"),
    vim.fn.expand("~/.local/bin/codex-acp"),
  })

  for _, path in ipairs(candidates) do
    if executable(path) then
      return { path }
    end
  end

  return { "codex-acp" }
end

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
              commands = {
                default = codex_acp_command(),
              },
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
