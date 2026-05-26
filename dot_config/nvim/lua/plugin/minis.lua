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
  },
  {
    "nvim-mini/mini.bracketed",
    version = false,
    event = "VeryLazy",
    config = function()
      require("mini.bracketed").setup({
        diagnostic = { suffix = "d" },
        quickfix = { suffix = "q" },

        buffer = { suffix = "" },
        comment = { suffix = "" },
        conflict = { suffix = "" },
        indent = { suffix = "" },
        jump = { suffix = "" },
        location = { suffix = "" },
        oldfile = { suffix = "" },
        treesitter = { suffix = "" },
        undo = { suffix = "" },
        window = { suffix = "" },
        yank = { suffix = "" },
      })
    end,
  },
}
