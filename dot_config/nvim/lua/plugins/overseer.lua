return {
    {
        "stevearc/overseer.nvim",
        opts = {
            templates = {
                "builtin",
                "cpp.gpp-run",
                "cpp.gpp-build-only",
                "cpp.gpp-debug",
            }
        },
      keys = {
            {"<LEADER>rr", "<cmd>OverseerRun<CR>", desc = "Run Task"},
            {"<LEADER>rl", "<cmd>OverseerRestartLastTask<CR>", desc = "Restart Last Task"},
            {"<LEADER>rt", "<cmd>OverseerToggle<CR>", desc = "Toggle Overseer"},
        }
    }
}
