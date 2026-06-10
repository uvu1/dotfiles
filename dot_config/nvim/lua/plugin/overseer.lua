return {
	{
		"stevearc/overseer.nvim",
		cmd = {
			"OverseerRun",
			"OverseerToggle",
			"OverseerQuickAction",
			"OverseerRestartLast",
			"OverseerInfo",
		},

		keys = function()
			return require("config.keymap.plugins.overseer")
		end,

		opts = {
			templates = {
				"builtin",
				"user.just",
			},

			strategy = {
				"terminal",
				direction = "bottom",
				size = 15,
			},

			task_list = {
				direction = "right",
				min_width = 32,
				max_width = 52,
				default_detail = 1,
			},

			form = {
				border = "rounded",
			},

			confirm = {
				border = "rounded",
			},

			task_win = {
				border = "rounded",
			},
		},
	},
}
