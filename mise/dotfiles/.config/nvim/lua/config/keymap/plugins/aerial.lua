local utils = require("config.keymap.utils")

return {
  utils.keymap.lazy("n", "<leader>o", "AerialToggle!", utils.opts("Toggle Aerial")),
  utils.keymap.lazy("n", "]]", "<cmd>AerialNext<CR>", utils.opts("Go to next symbol")),
  utils.keymap.lazy("n", "[[", "<cmd>AerialPrev<CR>", utils.opts("Go to previous symbol")),
}
