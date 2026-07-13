return {
  {
    "rachartier/tiny-inline-diagnostic.nvim",
    event = "LspAttach",
    priority = 1000,
    config = function ()
      vim.diagnostic.config({ virtual_text = false, virtual_lines = false })
      require("tiny-inline-diagnostic").setup({
        preset = "modern",
        options = {
          multilines = true,
        }
      })
    end
  }
}
