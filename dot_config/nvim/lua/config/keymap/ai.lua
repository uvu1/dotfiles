local base = require("config.keymap.base")

base.keymap("n", "<tab>", function ()
  local ok, sidekick = pcall(require, "sidekick")
  if ok and sidekick.nes_jump_or_apply() then
    return
  end
end, base.opts("Apply or Jump NES"))

base.keymap("v", "<leader>ad", "<cmd>CodeCompanionChat Add<cr>", base.opts("AI add selection to chat"))

base.keymap("n", "<leader>an", "<cmd>Sidekick nes update<cr>", base.opts("NES update"))
base.keymap("n", "<leader>aN", "<cmd>Sidekick nes toggle<cr>", base.opts("NES toggle"))
