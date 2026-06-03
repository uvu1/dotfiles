return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },

    opts = {
      formatters_by_ft = {
        -- Web
        typescript = { "biome", "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "biome", "prettierd", "prettier", stop_after_first = true },
        javascript = { "biome", "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "biome", "prettierd", "prettier", stop_after_first = true },

        json = { "biome", "prettierd", "prettier", stop_after_first = true },
        jsonc = { "biome", "prettierd", "prettier", stop_after_first = true },
        css = { "biome", "prettierd", "prettier", stop_after_first = true },

        -- Infra
        yaml = { "prettierd", "prettier", "yamlfmt", stop_after_first = true },

        -- Languages
        rust = { "rustfmt", lsp_format = "fallback" },
        python = { "ruff_format", "black", stop_after_first = true },
        cpp = { "clang_format", lsp_format = "fallback" },
        c = { "clang_format", lsp_format = "fallback" },

        -- Neovim config
        lua = { "stylua" },
      },

      format_on_save = function(bufnr)
        local ft = vim.bo[bufnr].filetype

        -- AI pane / terminal / prompt系は除外
        if vim.tbl_contains({
          "codecompanion",
          "pane-tabs-ai",
          "snacks_terminal",
        }, ft) then
          return
        end

        -- 巨大ファイルはformatしない
        local ok, stat = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(bufnr))
        if ok and stat and stat.size > 1024 * 1024 then
          return
        end

        return {
          timeout_ms = 1000,
          lsp_format = "fallback",
        }
      end,
    },

    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({
            async = true,
            lsp_format = "fallback",
          })
        end,
        desc = "Format Buffer",
      },
    },
  },
}
