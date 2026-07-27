local utils = require("config.keymap.utils")

return {
  utils.keymap.lazy("n", "<leader>dd", "DiffviewOpen", utils.opts("Diff working tree (Diffview)")),
  utils.keymap.lazy("n", "<leader>dm", "DiffviewOpen origin/HEAD...HEAD", utils.opts("Diff against merge base (Diffview)")),
  utils.keymap.lazy("n", "<leader>dh", "DiffviewFileHistory", utils.opts("Repository history (Diffview)")),
  utils.keymap.lazy("n", "<leader>df", "DiffviewFileHistory %", utils.opts("Current file history (Diffview)")),
  utils.keymap.lazy("n", "<leader>dt", "DiffviewToggleFiles", utils.opts("Toggle file panel (Diffview)")),
  utils.keymap.lazy("n", "<leader>dq", "DiffviewClose", utils.opts("Close Diffview")),
}
