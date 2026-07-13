local utils = require("config.keymap.utils")

return {
  utils.keymap.lazy("n", "<M-[>", function()
    require("pane-tabs.pane.editor").prev()
  end, utils.opts("Editor previous pane tab")),

  utils.keymap.lazy("n", "<M-]>", function()
    require("pane-tabs.pane.editor").next()
  end, utils.opts("Editor next pane tab")),

  utils.keymap.lazy("n", "<leader>a1", function()
    require("pane-tabs.pane.ai").open("copilot")
  end, utils.opts("AI tab1: Copilot")),

  utils.keymap.lazy("n", "<leader>a2", function()
    require("pane-tabs.pane.ai").open("codex")
  end, utils.opts("AI tab2: Codex")),

  utils.keymap.lazy("n", "<leader>a3", function()
    require("pane-tabs.pane.ai").open("claude")
  end, utils.opts("AI tab3: Claude")),

  utils.keymap.lazy("n", "<leader>aa", function()
    require("pane-tabs.pane.ai").toggle()
  end, utils.opts("AI toggle chat pane")),

  utils.keymap.lazy("n", "<leader>aq", function()
    require("pane-tabs.pane.ai").close()
  end, utils.opts("AI close chat pane")),

  utils.keymap.lazy("n", "<leader>al", "PaneTabsLoadAI", utils.opts("AI load session")),
  utils.keymap.lazy("n", "<leader>as", "PaneTabsSaveAI", utils.opts("AI save session")),
}
