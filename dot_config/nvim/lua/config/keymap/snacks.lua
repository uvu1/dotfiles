local base = require("config.keymap.base")
local snacks = require("snacks")

base.keymap("n", "<leader>e", function()
  local explorers = Snacks.picker.get({ source = "explorer" })

  for _, explorer in ipairs(explorers) do
    if explorer and not explorer.closed then
      explorer:focus("list")
      return
    end
  end

  Snacks.explorer.open({
    focus = "list",
    auto_close = false,
    layout = {
      preset = "sidebar",
      preview = false,
      hidden = { "input" },
    },
  })
end, base.opts("Focus or open explorer"))

base.keymap("n", "<leader>fe", function() snacks.explorer.open() end, base.opts("Toggle explorer"))
base.keymap("n", "<leader>E", function() snacks.explorer.reveal() end, base.opts("Reveal current file in explorer"))
base.keymap("n", "<leader>ff", function() snacks.picker.files() end, base.opts("Find files"))
base.keymap("n", "<leader>fg", function() snacks.picker.grep() end, base.opts("Grep"))
base.keymap("n", "<leader>fb", function() snacks.picker.buffers() end, base.opts("Buffers"))
base.keymap("n", "<leader>fd", function() snacks.picker.diagnostics() end, base.opts("Diagnostics"))
base.keymap("n", "<leader>fD", function() snacks.picker.diagnostics_buffer() end, base.opts("Buffer diagnostics"))
