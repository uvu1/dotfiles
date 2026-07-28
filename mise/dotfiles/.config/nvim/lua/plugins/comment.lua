return {
  -- ライン コメントは Neovim 0.10+ 組込の gcc/gc を使う。ts-comments は
  -- その commentstring を treesitter 対応させる。Comment.nvim は削除した。
  {
    "folke/ts-comments.nvim",
    opts = {},
    event = "VeryLazy",
    enabled = vim.fn.has("nvim-0.10.0") == 1,
  },
}
