return {
  {
--    dir = "~/repo/github.com/uvu1/pane-tabs.nvim",
    "uvu1/pane-tabs.nvim",
    name = "pane-tabs.nvim",
    main = "pane-tabs",
    event = "VeryLazy",
    cmd = {
      "PaneTabsOpenAI",
      "PaneTabsSwitchAI",
      "PaneTabsNextAI",
      "PaneTabsToggleAI",
      "PaneTabsFocusAI",
      "PaneTabsCloseAI",
      "PaneTabsMoveToAI",
      "PaneTabsPrevEditor",
      "PaneTabsNextEditor",
    },
    keys = {
      {
        "<M-[>",
        function()
          require("pane-tabs.pane.editor").prev()
        end,
        mode = "n",
        desc = "Editor previous pane tab",
      },
      {
        "<M-]>",
        function()
          require("pane-tabs.pane.editor").next()
        end,
        mode = "n",
        desc = "Editor next pane tab",
      },
      {
        "<leader>a1",
        function()
          require("pane-tabs.pane.ai").open("copilot")
        end,
        mode = { "n", "v" },
        desc = "AI tab1: Copilot",
      },
      {
        "<leader>a2",
        function()
          require("pane-tabs.pane.ai").open("codex")
        end,
        mode = { "n", "v" },
        desc = "AI tab2: Codex",
      },
      {
        "<leader>aa",
        function()
          require("pane-tabs.pane.ai").toggle()
        end,
        mode = { "n", "v" },
        desc = "AI toggle chat pane",
      },
      {
        "<leader>aq",
        function()
          require("pane-tabs.pane.ai").close()
        end,
        mode = "n",
        desc = "AI close chat pane",
      },
    },
    opts = {
      ai = {
        enabled = true,
        width = 52,
        default_provider = "copilot",
        provider_order = { "copilot", "codex" },
        providers = {
          copilot = {
            name = "Copilot",
            label = " Copilot",
            icon = "",
            adapter = "copilot",
            command = "CodeCompanionChat",
          },
          codex = {
            name = "Codex",
            label = "󰚩 Codex",
            icon = "󰚩",
            adapter = "codex",
            command = "CodeCompanionChat",
          },
        },
      },
    },
  },
}
