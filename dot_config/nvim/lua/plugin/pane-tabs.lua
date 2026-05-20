return {
  {
    -- dir = "~/repo/github.com/uvu1/pane-tabs.nvim",
    "uvu1/pane-tabs.nvim",
    name = "pane-tabs.nvim",
    main = "pane-tabs",
    event = "VeryLazy",
    cmd = {
      "PaneTabsOpenAI",
      "PaneTabsNewAI",
      "PaneTabsSwitchAI",
      "PaneTabsNextAI",
      "PaneTabsToggleAI",
      "PaneTabsFocusAI",
      "PaneTabsCloseAI",
      "PaneTabsMoveToAI",
      "PaneTabsPrevEditor",
      "PaneTabsNextEditor",
      "PaneTabsSaveAI",
      "PaneTabsLoadAI",
      "PaneTabsDeleteAI",
    },
    keys = function() return require("config.keymap.plugins.pane-tabs") end,
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
