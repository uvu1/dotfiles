return {
  {
    "nvim-mini/mini.pairs",
    event = "InsertEnter",
    config = function ()
      require("mini.pairs").setup()
      vim.keymap.set("i", "<CR>", function ()
        return require("mini.pairs").cr()
      end, { expr = true, replace_keycodes = true, })
    end
  },
  {
    "nvim-mini/mini.surround",
    event = "InsertEnter",
    opts = {}
  },
  {
    "nvim-mini/mini.icons",
    event = "VeryLazy",
    setup = function ()
      require("mini.icons").setup()
      MiniIcons.mock_nvim_web_devicons()
    end
  }
}
