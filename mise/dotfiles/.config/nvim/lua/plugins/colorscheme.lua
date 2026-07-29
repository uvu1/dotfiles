return {
  {
    "uvu1/kawaii-theme.nvim",
    name = "kawaii-theme.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      -- ComplHint は runtime の colors/vim.lua が NonText にリンクし、kawaii は
      -- NonText をウィンドウ枠線色 p.border にする。結果 vim.lsp.inline_completion の
      -- ゴーストテキストが背景と同化して実質見えない。本来の直し先は kawaii-theme 側の
      -- hl("ComplHint", ...) なので、上流に入れたらこのブロックごと削除する。
      -- ComplHintMore は MoreMsg（p.green）で読めているため触らない。
      -- colorscheme 適用のたびに hi clear されるので autocmd を唯一の呼び出し口にする。
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("kawaii-ghost-text", { clear = true }),
        pattern = "kawaii-theme",
        callback = function()
          local p = require("kawaii-theme.palette")
          vim.api.nvim_set_hl(0, "ComplHint", { fg = p.muted, italic = true })
        end,
      })

      require("kawaii-theme").setup({
        transparent = true,
      })
      vim.cmd.colorscheme("kawaii-theme")
    end,
  },
}
