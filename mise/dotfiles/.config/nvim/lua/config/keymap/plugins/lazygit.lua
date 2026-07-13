local utils = require("config.keymap.utils")

return {
  utils.keymap.lazy({ "n", "t" }, "<leader>tl", "LazyGit", utils.opts("Toggle lazygit")),
}
