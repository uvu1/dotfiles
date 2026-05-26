return {
	{
		"folke/sidekick.nvim",
		event = "VeryLazy",
		opts = {
			nes = {
				enabled = true,
				debounce = 400,
				trigger = {
					events = { "ModeChanged i:n", "User SidekickNesDone" },
				},
				diff = {
					inline = false,
					show = "cursor",
				},
				signs = true,
				jumplist = true,
				cli = { enabled = false },
			},
		},
		keys = function()
			return require("config.keymap.plugins.sidekick")
		end,
	},
}
