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

      -- form / task_win の border は書かない。overseer の既定が nil で
      -- nvim_open_win に素通しするため winborder が効く。
      -- confirm = { border } は overseer が一度も読まない死んだ設定だったので削除した。
    },
  },
}
