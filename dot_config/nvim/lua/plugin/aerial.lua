return {
  {
    "stevearc/aerial.nvim",
    opts = {
      backends = { "lsp", "treesitter", "markdown" },
      filter_kind = {
        "Class",
        "Constructor",
        "Enum",
        "Function",
        "Interface",
        "Module",
        "Method",
        "Struct",
      },
      show_guides = true,
      layout = {
        default_direction = "prefer_right",
        max_width = 40,
        min_width = 20,
        placement = "window",
      },
    },
    keys = function() return require("config.keymap.plugins.aerial") end,
  }
}
