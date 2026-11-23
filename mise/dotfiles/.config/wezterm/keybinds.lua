local wezterm = require("wezterm")
local act = wezterm.action

local function apply(config)
  config.disable_default_key_bindings = true

  local ctrl_shift = "CTRL|SHIFT"
  local search = act.Search({ CaseInSensitiveString = "" })
  local url = [=[(?:https?://|mailto:|file:|ssh://|git://)[^\s<>"'`]+]=]

  config.quick_select_patterns = {
    url,
    [[\b[0-9a-f]{7,40}\b]],
    [[\b[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+\b]],
    [[\b(?:issues|pull)/[0-9]+\b]],
    [[[\w./~_-]+:\d+]],
    [[\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{2,5}\b]],
    [[\b[a-z0-9](?:[-a-z0-9]*[a-z0-9])?-[a-z0-9]{8,10}-[a-z0-9]{5}\b]],
    [[\b[A-Za-z0-9-]+/[A-Za-z0-9-]+\b]],
    [[\b[a-zA-Z0-9.-]+\.(?:dev|local|me|com|net|org|io|jp)\b]],
    [[\b[A-Za-z]:\\[^\s:*?"<>|]+]],
    [[\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[A-Za-z]+\b]],
  }

  config.keys = {
    { key = "p", mods = ctrl_shift, action = act.ActivateCommandPalette },
    { key = "c", mods = ctrl_shift, action = act.CopyTo("Clipboard") },
    { key = "v", mods = ctrl_shift, action = act.PasteFrom("Clipboard") },
    { key = "f", mods = ctrl_shift, action = search },
    { key = "b", mods = ctrl_shift, action = search },
    { key = "n", mods = ctrl_shift, action = act.SpawnWindow },
    { key = "r", mods = ctrl_shift, action = act.ReloadConfiguration },
    { key = "l", mods = ctrl_shift, action = act.ShowDebugOverlay },
    {
      key = ",",
      mods = ctrl_shift,
      action = wezterm.action_callback(function()
        wezterm.open_with(wezterm.config_file)
      end),
    },
    { key = "Enter", mods = ctrl_shift, action = act.ToggleFullScreen },
    { key = "0", mods = "CTRL", action = act.ResetFontSize },
    { key = "=", mods = "CTRL", action = act.IncreaseFontSize },
    { key = "+", mods = "CTRL", action = act.IncreaseFontSize },
    { key = "-", mods = "CTRL", action = act.DecreaseFontSize },
    { key = "Space", mods = ctrl_shift, action = act.QuickSelect },
    {
      key = "o",
      mods = ctrl_shift,
      action = act.QuickSelectArgs({
        label = "open URL",
        patterns = { url },
        skip_action_on_paste = true,
        action = wezterm.action_callback(function(window, pane)
          wezterm.open_with(window:get_selection_text_for_pane(pane))
        end),
      }),
    },
    -- Claude Code の改行と Neovim のバッファ移動を端末の入力モードに依存させない。
    { key = "Enter", mods = "SHIFT", action = act.SendString("\x1b\r") },
    { key = "[", mods = "ALT", action = act.SendString("\x1b[91;3u") },
    { key = "]", mods = "ALT", action = act.SendString("\x1b[93;3u") },
    -- 従来の入力では Ctrl+Shift と Ctrl を区別できないので、コピーは CSI u で送る。
    { key = "x", mods = ctrl_shift, action = act.SendString("\x1b[120;6u") },
    { key = "t", mods = "CTRL", action = act.SpawnTab("CurrentPaneDomain") },
    { key = "w", mods = "CTRL", action = act.CloseCurrentTab({ confirm = true }) },
  }
  for tab = 1, 9 do
    local key = "phys:" .. tab
    table.insert(config.keys, { key = key, mods = ctrl_shift, action = act.ActivateTab(tab - 1) })
    -- Herdr のクライアントに Ctrl+Q プレフィックスとタブ番号を送る。
    table.insert(config.keys, { key = key, mods = "CTRL", action = act.SendString("\x11" .. tab) })
  end

  config.key_tables = {
    search_mode = {
      { key = "Enter", action = act.CopyMode("PriorMatch") },
      { key = "Escape", action = act.CopyMode("Close") },
      { key = "n", mods = "CTRL", action = act.CopyMode("NextMatch") },
      { key = "p", mods = "CTRL", action = act.CopyMode("PriorMatch") },
      { key = "r", mods = "CTRL", action = act.CopyMode("CycleMatchType") },
      { key = "u", mods = "CTRL", action = act.CopyMode("ClearPattern") },
      { key = "PageUp", action = act.CopyMode("PriorMatchPage") },
      { key = "PageDown", action = act.CopyMode("NextMatchPage") },
      { key = "UpArrow", action = act.CopyMode("PriorMatch") },
      { key = "DownArrow", action = act.CopyMode("NextMatch") },
      { key = "f", mods = ctrl_shift, action = act.CopyMode("NextMatch") },
      { key = "b", mods = ctrl_shift, action = act.CopyMode("PriorMatch") },
    },
  }

  config.mouse_bindings = {
    {
      event = { Up = { streak = 1, button = "Left" } },
      mods = "NONE",
      action = act.CompleteSelectionOrOpenLinkAtMouseCursor("ClipboardAndPrimarySelection"),
    },
  }
end

return apply
