return {
  {
    "mason-org/mason.nvim",
    opts = {},
  },

  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
      "b0o/schemastore.nvim",
    },
    config = function()
      local ai_filetypes = {
        codecompanion = true,
        ["pane-tabs-ai"] = true,
      }

      local yaml_schemas = require("schemastore").yaml.schemas()
      yaml_schemas.kubernetes = {
        "k8s/**/*.yaml",
        "k8s/**/*.yml",
        "kubernetes/**/*.yaml",
        "kubernetes/**/*.yml",
        "manifests/**/*.yaml",
        "manifests/**/*.yml",
        "clusters/**/*.yaml",
        "clusters/**/*.yml",
        "applications/**/*.yaml",
        "applications/**/*.yml",
        "applicatinsets/**/*.yaml",
        "applicationsets/**/*.yml",
      }

      vim.lsp.config("yamlls", {
        settings = {
          redhat = {
            telemetry = {
              enabled = false,
            },
          }
        },
        yaml = {
          validate = true,
          completion = true,
          hover = true,

          keyOrdering = false,
          schemaStore = {
            enable = false,
            url = "",
          },
          schemas = yaml_schemas,
        }
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = {
              version = "LuaJIT",
            },
            diagnostics = {
              globals = { "vim" },
            },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = {
              enable = false,
            },
          },
        },
      })

      vim.lsp.config("ts_ls", {})

      vim.lsp.config("rust_analyzer", {
        settings = {
          ["rust-analyzer"] = {
            cargo = {
              allFeatures = true,
            },
            check = {
              command = "clippy",
            },
          },
        },
      })

      -- for Sidekick NES
      vim.lsp.config("copilot", {})

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("ai-pane-completion", { clear = true }),
        pattern = { "codecompanion", "pane-tabs-ai" },
        callback = function(args)
          vim.b[args.buf].completion = false

          if vim.lsp.inline_completion then
            vim.lsp.inline_completion.enable(false, { bufnr = args.buf })
          end
        end,
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("copilot-inline", { clear = true }),
        callback = function (args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then
            return
          end

          if client.name == "copilot" then
            vim.lsp.inline_completion.enable(not ai_filetypes[vim.bo[args.buf].filetype], { bufnr = args.buf })
          end
        end
      })
    end,
  },

  {
    "mason-org/mason-lspconfig.nvim",
    event = { "VeryLazy", "BufReadPre" },
    dependencies = {
      "mason-org/mason.nvim",
      "neovim/nvim-lspconfig",
     },
    opts = {
      ensure_installed = {
        "copilot",
        "lua_ls",
        "rust_analyzer",
        "ts_ls",
        "biome",
        "jsonls",
        "yamlls",
        "html",
        "cssls",
        "tailwindcss",
        "pyright",
      },

      automatic_enable = true,
    },
  },
}
