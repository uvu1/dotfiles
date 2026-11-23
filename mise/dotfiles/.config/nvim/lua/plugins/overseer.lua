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
      -- templates と strategy は書かない。現在の overseer はどちらも読まない。
      -- ・テンプレートは runtimepath の lua/overseer/template/**/*.lua を常に
      --   全部読む（overseer/template.lua の get_providers）。除外したいときは
      --   disable_template_modules を使う。mise のタスクは overseer 同梱の
      --   template/mise.lua が `mise tasks --json` から拾うので、
      --   <leader>rr にそのまま並ぶ（実測で build / lint を検出）。
      -- ・strategy は task 単位のオプションに移り、overseer.Config には無い
      --   （doc/strategies.md）。出力バッファの指定は output.use_terminal。
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

    config = function(_, opts)
      local overseer = require("overseer")
      overseer.setup(opts)
      -- just の探索・引数入力・cwd は内蔵版へ任せ、出力の quickfix 連携だけ補う。
      overseer.add_template_hook({ module = "^just$" }, function(task, util)
        util.add_component(task, "on_output_quickfix")
      end)
    end,
  },
}
