local utils = require("config.keymap.utils")

return {
  utils.keymap.lazy("n", "<leader>xx", "Trouble diagnostics toggle", utils.opts("Diagnostics (Trouble)")),
  utils.keymap.lazy("n", "<leader>xX", "Trouble diagnostics toggle filter.buf=0", utils.opts("Buffer Diagnostics (Trouble)")),
  utils.keymap.lazy("n", "<leader>cs", "Trouble symbols toggle focus=false", utils.opts("Symbols (Trouble)")),
  utils.keymap.lazy("n", "<leader>cl", "Trouble lsp toggle focus=false win.position=bottom", utils.opts("LSP Definitions / References (Trouble)")),
  utils.keymap.lazy("n", "<leader>xQ", "Trouble qflist toggle", utils.opts("Quickfix List (Trouble)")),
}
