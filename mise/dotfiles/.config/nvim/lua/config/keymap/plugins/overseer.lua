local utils = require("config.keymap.utils")

return {
	utils.keymap.lazy("n", "<leader>rr", "OverseerRun", utils.opts("Run task")),
	utils.keymap.lazy("n", "<leader>rt", "OverseerToggle", utils.opts("Toggle tasks")),
	utils.keymap.lazy("n", "<leader>ra", "OverseerQuickAction", utils.opts("Task action")),
	utils.keymap.lazy("n", "<leader>rl", "OverseerRestartLast", utils.opts("Restart last task")),
	utils.keymap.lazy("n", "<leader>ri", "OverseerInfo", utils.opts("Overseer info")),
}
