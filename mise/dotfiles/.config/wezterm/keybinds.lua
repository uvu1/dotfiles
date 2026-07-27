local wezterm = require("wezterm")
local workspaces = require("workspaces")
local module = {}

function module.apply(config)
  config.disable_default_key_bindings = true

  config.leader = {
    key = "q",
    mods = "CTRL",
    timeout_milliseconds = 2500,
  }

  config.quick_select_patterns = {
    -- Git SHA
    [[\b[0-9a-f]{7,40}\b]],

    -- GitHub owner/repo#123
    [[\b[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+\b]],

    -- GitHub issue/PR URL-ish
    [[\bissues/[0-9]+\b]],
    [[\bpull/[0-9]+\b]],

    -- Kubernetes namespace/name
    [[\b[A-Za-z0-9-]+/[A-Za-z0-9_.-]+\b]],

    -- Kubernetes pod-ish
    [[\b[a-z0-9]([-a-z0-9]*[a-z0-9])?-[a-z0-9]{8,10}-[a-z0-9]{5}\b]],

    -- IPv4:port
    [[\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{2,5}\b]],

    -- domain
    [[\b[a-zA-Z0-9.-]+\.(?:dev|local|me|com|net|org|io|jp)\b]],

    -- file:line
    [[[\w./~_-]+:\d+]],

    -- windows path
    [[\b[A-Za-z]:\\[^\s:*?"<>|]+\b]],

    -- email
    [[\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+\b]],
  }

  -- リサイズはモーダルにして CTRL|SHIFT+hjkl を解放する。one_shot = false なので
  -- table に入ったあとは hjkl の連打で調整でき、Escape / CTRL-g で抜ける。
  config.key_tables = {
    resize_pane = {
      { key = "h", action = wezterm.action.AdjustPaneSize({ "Left", 3 }) },
      { key = "l", action = wezterm.action.AdjustPaneSize({ "Right", 3 }) },
      { key = "j", action = wezterm.action.AdjustPaneSize({ "Down", 3 }) },
      { key = "k", action = wezterm.action.AdjustPaneSize({ "Up", 3 }) },
      { key = "Escape", action = "PopKeyTable" },
      { key = "g", mods = "CTRL", action = "PopKeyTable" },
    },
  }

  config.keys = {
    -- wezterm features
    { key = "p", mods = "CTRL|SHIFT", action = wezterm.action.ActivateCommandPalette },
    { key = "x", mods = "CTRL|SHIFT", action = wezterm.action.ActivateCopyMode },
    { key = "Space", mods = "CTRL|SHIFT", action = wezterm.action.QuickSelect },
    -- copy/paste
    { key = "c", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("Clipboard") },
    { key = "v", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard") },
    -- pane
    { key = "z", mods = "LEADER", action = wezterm.action.TogglePaneZoomState },
    { key = "h", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Left") },
    { key = "l", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Right") },
    { key = "j", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Down") },
    { key = "k", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Up") },
    { key = "/", mods = "LEADER", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "-", mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = false }) },
    -- ペインが 3 枚以上になると hjkl の方向指定では狙えないためラベル選択する。
    { key = "Space", mods = "LEADER", action = wezterm.action.PaneSelect },
    { key = "s", mods = "LEADER", action = wezterm.action.PaneSelect({ mode = "SwapWithActive" }) },
    {
      key = "r",
      mods = "LEADER",
      action = wezterm.action.ActivateKeyTable({
        name = "resize_pane",
        one_shot = false,
        timeout_milliseconds = 2000,
      }),
    },
    -- workspace
    { key = "w", mods = "LEADER", action = wezterm.action.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
    {
      key = "W",
      mods = "LEADER",
      action = wezterm.action.PromptInputLine({
        description = "New workspace name",
        action = wezterm.action_callback(function(window, pane, line)
          if line and line ~= "" then
            window:perform_action(wezterm.action.SwitchToWorkspace({ name = line }), pane)
          end
        end),
      }),
    },
    -- zsh 側の ghq-fzf (bindkey ^g) と同じ操作感で workspace を開く。
    { key = "g", mods = "LEADER", action = workspaces.ghq_selector() },
    { key = "[", mods = "LEADER", action = wezterm.action.SwitchWorkspaceRelative(-1) },
    { key = "]", mods = "LEADER", action = wezterm.action.SwitchWorkspaceRelative(1) },
    -- tab
    { key = "t", mods = "CTRL|SHIFT", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
    { key = "w", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentTab({ confirm = false }) },
    -- quit
    { key = "q", mods = "LEADER|CTRL", action = wezterm.action.QuitApplication },
  }

  config.mouse_bindings = {
    -- 左ドラッグで選択を確定した時点でクリップボードへコピー(リンクならクリックで開く)
    {
      event = { Up = { streak = 1, button = "Left" } },
      mods = "NONE",
      action = wezterm.action.CompleteSelectionOrOpenLinkAtMouseCursor("ClipboardAndPrimarySelection"),
    },
    -- 右クリックでクリップボードからペースト
    {
      event = { Down = { streak = 1, button = "Right" } },
      mods = "NONE",
      action = wezterm.action.PasteFrom("Clipboard"),
    },
  }

  -- switch to tab 1-8 with leader + number
  for i = 1, 8 do
    table.insert(config.keys, {
      key = tostring(i),
      mods = "CTRL",
      action = wezterm.action.ActivateTab(i - 1),
    })
  end
end

return module
