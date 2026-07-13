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

  utils.keymap.lazy("n", "<leader>gd", function() require("snacks").picker.lsp_definitions() end, utils.opts("Go to definitions")),
  utils.keymap.lazy("n", "<leader>gr", function() require("snacks").picker.lsp_references() end, utils.opts("Go to references")),
  utils.keymap.lazy("n", "<leader>gi", function() require("snacks").picker.lsp_implementations() end, utils.opts("Go to implementations")),
  utils.keymap.lazy("n", "<leader>gy", function() require("snacks").picker.lsp_type_definitions() end, utils.opts("Go to type definitions")),
  utils.keymap.lazy("n", "<leader>grn", function() require("snacks").lsp.rename() end, utils.opts("Rename symbol")),
  utils.keymap.lazy("n", "<leader>gci", function() require("snacks").lsp.incoming_calls() end, utils.opts("Incoming calls")),
  utils.keymap.lazy("n", "<leader>gco", function() require("snacks").lsp.outgoing_calls() end, utils.opts("Outgoing calls")),
  utils.keymap.lazy("n", "<leader>ss", function() require("snacks").picker.lsp_symbols() end, utils.opts("File symbols")),
  utils.keymap.lazy("n", "<leader>sS", function() require("snacks").picker.lsp_workspace_symbols() end, utils.opts("Workspace symbols")),

  utils.keymap.lazy("n", "<leader>sf",
    function()
      require("snacks").picker.lsp_symbols({
        title = "Functions",
        filter = {
          default = { "Function", "Method", "Constructor" },
        }
      })
    end,
    utils.opts("File functions")
  ),

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
