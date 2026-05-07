local base = require("config.keymap.base")

base.keymap("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", base.opts("Diagnostics (Trouble)"))
base.keymap("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", base.opts("Buffer Diagnostics (Trouble)"))
base.keymap("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", base.opts("Symbols (Trouble)"))
base.keymap("n", "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", base.opts("LSP Definitions / References (Trouble)"))
base.keymap("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", base.opts("Quickfix List (Trouble)"))
