local utils = require("config.keymap.utils")

return {
  utils.keymap.lazy("n", "]f", function()
    require("nvim-treesitter.textobjects.move").goto_next_start("@function.outer", "textobjects")
  end, utils.opts("Go to next function start")),

  utils.keymap.lazy("n", "[f", function()
    require("nvim-treesitter.textobjects.move").goto_previous_start("@function.outer", "textobjects")
  end, utils.opts("Go to previous function start")),

  utils.keymap.lazy("n", "]F", function ()
    require("nvim-treesitter.textobjects.move").goto_next_end("@function.outer", "textobjects")
  end, utils.opts("Go to next function end")),

  utils.keymap.lazy("n", "[F", function ()
    require("nvim-treesitter.textobjects.move").goto_previous_end("@function.outer", "textobjects")
  end, utils.opts("Go to previous function end")),
}
