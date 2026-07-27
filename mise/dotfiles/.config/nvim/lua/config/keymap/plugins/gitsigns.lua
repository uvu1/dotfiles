local utils = require("config.keymap.utils")

return {
  utils.keymap.lazy("n", "<leader>db", "Gitsigns blame", utils.opts("Blame file (gitsigns)")),
  utils.keymap.lazy("n", "<leader>dB", "Gitsigns blame_line", utils.opts("Blame current line (gitsigns)")),
}
