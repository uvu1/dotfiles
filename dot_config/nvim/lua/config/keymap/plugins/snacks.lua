local utils = require("config.keymap.utils")

return {
	utils.keymap.lazy("n", "<leader>e", function()
		local snacks = require("snacks")
		local explorers = snacks.picker.get({ source = "explorer" })

		for _, explorer in ipairs(explorers) do
			if explorer and not explorer.closed then
				explorer:focus("list")
				return
			end
		end

		snacks.explorer.open({
			focus = "list",
			auto_close = false,
			layout = {
				preset = "sidebar",
				preview = false,
				hidden = { "input" },
			},
		})
	end, utils.opts("Focus or open explorer")),

	utils.keymap.lazy("n", "<leader>fe", function() require("snacks").explorer.open() end, utils.opts("Toggle explorer")),
	utils.keymap.lazy("n", "<leader>E", function() require("snacks").explorer.reveal() end, utils.opts("Reveal current file in explorer")),
	utils.keymap.lazy("n", "<leader>ff", function() require("snacks").picker.files() end, utils.opts("Find files")),
	utils.keymap.lazy("n", "<leader>fg", function() require("snacks").picker.grep() end, utils.opts("Grep")),
	utils.keymap.lazy("n", "<leader>fb", function() require("snacks").picker.buffers() end, utils.opts("Buffers")),
	utils.keymap.lazy("n", "<leader>fr", function() require("snacks").picker.recent() end, utils.opts("Recent files")),
	utils.keymap.lazy("n", "<leader>fd", function() require("snacks").picker.diagnostics() end, utils.opts("Diagnostics")),
	utils.keymap.lazy("n", "<leader>fD", function() require("snacks").picker.diagnostics_buffer() end, utils.opts("Buffer diagnostics")),
	utils.keymap.lazy("n", "<leader>fc", function()
    require("snacks").picker.files({ cwd = vim.fn.stdpath("config") })
  end, utils.opts("Find config files")),
}
