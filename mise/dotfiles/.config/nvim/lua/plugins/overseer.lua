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

    keys = {
      { "<leader>rr", "<cmd>OverseerRun<cr>", desc = "Run task" },
      { "<leader>rt", "<cmd>OverseerToggle<cr>", desc = "Toggle tasks" },
      { "<leader>ra", "<cmd>OverseerQuickAction<cr>", desc = "Task action" },
      { "<leader>rl", "<cmd>OverseerRestartLast<cr>", desc = "Restart last task" },
      { "<leader>ri", "<cmd>OverseerInfo<cr>", desc = "Overseer info" },
    },

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
