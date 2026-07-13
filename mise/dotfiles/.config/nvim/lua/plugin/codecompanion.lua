local function executable(path)
  return type(path) == "string" and path ~= "" and vim.fn.executable(path) == 1
end

local function resolve_acp_command(binary)
  local from_path = vim.fn.exepath(binary)

  if executable(from_path) then
    return { from_path }
  end

  local candidates = vim.fn.glob(vim.fn.expand("~/.local/share/mise/installs/node/*/bin/" .. binary), false, true)

  table.sort(candidates, function(a, b)
    return a > b
  end)

  vim.list_extend(candidates, {
    vim.fn.expand("~/.local/share/mise/shims/" .. binary),
    vim.fn.expand("~/.local/bin/" .. binary),
  })

  for _, path in ipairs(candidates) do
    if executable(path) then
      return { path }
    end
  end

  return { binary }
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
                default = resolve_acp_command("codex-acp"),
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
          claude_code = function()
            return require("codecompanion.adapters").extend("claude_code", {
              commands = {
                default = resolve_acp_command("claude-agent-acp"),
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
