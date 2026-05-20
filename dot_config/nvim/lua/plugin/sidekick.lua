return {
	{
		"folke/sidekick.nvim",
		event = "VeryLazy",
		opts = {
			nes = {
				enabled = true,
				debounce = 120,
				diff = {
					inline = "words",
					show = "always",
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
