return {
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    init = function()
      -- Visual の S は Flash Treesitter に残す。
      vim.g.nvim_surround_no_visual_mappings = true
    end,
    keys = {
      { "gS", "<Plug>(nvim-surround-visual)", mode = "x", desc = "Add surrounding pair" },
    },
  },
}
