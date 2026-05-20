local utils = require("config.keymap.utils")

return {
  utils.keymap.lazy("n", "<tab>", function ()
    local ok, sidekick = pcall(require, "sidekick")
    if ok and sidekick.nes_jump_or_apply() then
      return
    end
  end, utils.opts("Apply or Jump NES")),
}

