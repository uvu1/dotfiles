-- nvim-treesitter (main ブランチ) のトップレベル spec。
-- 従来は他プラグインの dependencies 経由でのみ取得され、パーサが 1 つも
-- インストールされていなかった（Neovim 同梱の 7 つのみ）。ここで install() を
-- 呼び、Neovim 0.12 が自動有効化しない treesitter を FileType で自分で start する。
return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    config = function()
      -- main ブランチに ensure_installed は無い。install() が未導入分のみ取得する（async）。
      local langs = {
        "lua",
        "python",
        "rust",
        "typescript",
        "tsx",
        "javascript",
        "json",
        "yaml",
        "css",
        "html",
        "bash",
        "markdown",
        "markdown_inline",
        "toml",
      }
      require("nvim-treesitter").install(langs)

      -- Neovim 0.12 は treesitter を自動有効化しない（同梱 ftplugin で start するのは
      -- help/lua/markdown/query のみ）。通常バッファで自分で start する。
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter-start", { clear = true }),
        callback = function(args)
          if vim.bo[args.buf].buftype ~= "" then
            return
          end

          local lang = vim.treesitter.language.get_lang(args.match) or args.match
          -- パーサ未着（install は async）や二重 start は pcall で吸収する。
          pcall(vim.treesitter.start, args.buf, lang)
        end,
      })
    end,
  },
}
