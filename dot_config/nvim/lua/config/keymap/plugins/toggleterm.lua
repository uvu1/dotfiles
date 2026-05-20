local utils = require("config.keymap.utils")

return {
  utils.keymap.lazy({ "n", "t" }, "<leader>tt", "ToggleTerm", utils.opts("Toggle terminal")),
}
