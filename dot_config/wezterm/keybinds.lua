local wezterm = require("wezterm")
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

  config.keys = {
    -- wezterm features
    { key = "p", mods = "CTRL|SHIFT", action = wezterm.action.ActivateCommandPalette },
    { key = "x", mods = "CTRL|SHIFT", action = wezterm.action.ActivateCopyMode },
    { key = "Space", mods = "CTRL|SHIFT", action = wezterm.action.QuickSelect },
    -- copy/paste
    { key = "c", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("Clipboard") },
    { key = "v", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard") },
    -- pane
    { key = "h", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Left") },
    { key = "l", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Right") },
    { key = "j", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Down") },
    { key = "k", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Up") },
    { key = "/", mods = "LEADER", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
    { key = "-", mods = "LEADER", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
    { key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = false }) },
    -- tab
    { key = "t", mods = "CTRL|SHIFT", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
    { key = "w", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentTab({ confirm = false }) },
    -- quit
    { key = "q", mods = "LEADER|CTRL", action = wezterm.action.QuitApplication },
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
