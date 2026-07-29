local project = require("lib.project")

local function web_formatters(bufnr)
  if project.uses_prettier(bufnr) then
    return { "prettier" }
  end

  if project.uses_biome(bufnr) then
    return { "biome" }
  end

  return { "biome", "prettier", stop_after_first = true }
end

return {
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },

    opts = {
      formatters_by_ft = {
        typescript = web_formatters,
        typescriptreact = web_formatters,
        javascript = web_formatters,
        javascriptreact = web_formatters,
        json = web_formatters,
        jsonc = web_formatters,
        css = web_formatters,

        yaml = { "prettier" },
        rust = { "rustfmt", lsp_format = "fallback" },
        python = { "ruff_format" },
        -- goimports が import を整理し、gofumpt が gofmt より厳しく整形する。
        go = { "goimports", "gofumpt" },
        -- ruby / haml は formatters_by_ft に置かない。ruby は ruby-lsp が
        -- プロジェクトの bundle にある rubocop で整形するので、下の
        -- format_on_save の lsp_format = "fallback" 経由に任せる方が正しい
        -- （グローバルの rubocop では .rubocop.yml が参照する plugin gem を
        -- 読めず落ちる）。haml は conform に formatter が存在しない。
        -- clang_format は conform の非推奨エイリアス。clang-format が正名。
        cpp = { "clang-format", lsp_format = "fallback" },
        c = { "clang-format", lsp_format = "fallback" },
        lua = { "stylua" },
      },

      format_on_save = function(bufnr)
        local ft = vim.bo[bufnr].filetype

        if
          vim.tbl_contains({
            "codecompanion",
            "pane-tabs-ai",
            "snacks_terminal",
            "terminal",
            "prompt",
          }, ft)
        then
          return
        end

        local name = vim.api.nvim_buf_get_name(bufnr)
        if name == "" then
          return
        end

        local ok, stat = pcall(vim.uv.fs_stat, name)
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
        desc = "Format buffer",
      },
    },
  },
}
