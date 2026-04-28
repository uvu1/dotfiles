local wezterm = require("wezterm")
local module = {}

function module.apply(config)
    config.disable_default_key_bindings = true
    config.leader = {
        key = "q",
        mods = "CTRL",
        timeout_milliseconds = 2500,
    }
    config.keys = {
        -- copy/paste
        { key = "c", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("Clipboard"), },
        { key = "v", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard"), },
        -- pane
        { key = "h", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Left"), },
        { key = "l", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Right"), },
        { key = "j", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Down"), },
        { key = "k", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Up"), },
        { key = "-", mods = "LEADER", action = wezterm.action.SplitHorizontal { domain = "CurrentPaneDomain" }, },
        { key = "/", mods = "LEADER", action = wezterm.action.SplitVertical { domain = "CurrentPaneDomain" }, },
        { key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane { confirm = false }, },
        -- tab
        { key = "t", mods = "CTRL|SHIFT", action = wezterm.action.SpawnTab("CurrentPaneDomain"), },
        { key = "w", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentTab { confirm = false }, },
        -- quit
        { key = "q", mods = "LEADER|CTRL", action = wezterm.action.QuitApplication, },
    }

    -- switch to tab 1-8 with leader + number
    for i = 1,8 do
        table.insert(config.keys, {
            key = tostring(i),
            mods = "CTRL",
            action = wezterm.action.ActivateTab(i - 1),
        })
    end
end

return module