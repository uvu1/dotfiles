return {
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    depencencies = { "nvim-treesitter/nvim-treesitter" },
    branch = "main",
    config = function()
      local select = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")
      local swap = require("nvim-treesitter-textobjects.swap")

      require("nvim-treesitter-textobjects").setup({
        select = { lookahead = true },
        move = { set_jumps = true },
      })
    end,
    keys = function() return require("config.keymap.plugins.treesitter-textobjects") end,
  }
}
