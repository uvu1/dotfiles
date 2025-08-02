local wezterm = require("wezterm")
local module = {}

function module.apply_config(config)
    config.disable_default_key_bindings = true
    config.leader = {
        key = "q",
        mods = "CTRL",
        timeout_milliseconds = 2000,
    }
    config.keys = {
        {
            key = "v",
            mods = "CTRL|SHIFT",
            action = wezterm.action.PasteFrom("Clipboard"),
        },
        {
            key = "c",
            mods = "CTRL|SHIFT",
            action = wezterm.action.CopyTo("Clipboard"),
        },
        -- Add keybindings for move between words with vim style
        {
            key = "f",
            mods = "CTRL",
            action = wezterm.action.SendKey({
                key = "f",
                mods = "META",
            })
        },
        {
            key = "b",
            mods = "CTRL",
            action = wezterm.action.SendKey({
                key = "b",
                mods = "META",
            })
        },
        -- Move pane
        {
            key = "h",
            mods = "LEADER",
            action = wezterm.action.ActivatePaneDirection("Left"),
        },
        {
            key = "j",
            mods = "LEADER",
            action = wezterm.action.ActivatePaneDirection("Down"),
        },
        {
            key = "k",
            mods = "LEADER",
            action = wezterm.action.ActivatePaneDirection("Up"),
        },
        {
            key = "l",
            mods = "LEADER",
            action = wezterm.action.ActivatePaneDirection("Right"),
        },
        {
            key = "x",
            mods = "LEADER",
            action = wezterm.action.CloseCurrentPane({ confirm = true }),
        },
        {
            key = "w",
            mods = "LEADER",
            action = wezterm.action.CloseCurrentTab({ confirm = false }),
        },
        {
            key = "c",
            mods = "LEADER",
            action = wezterm.action.SpawnTab("CurrentPaneDomain")
        },
        {
            key = "/",
            mods = "LEADER",
            action = wezterm.action.SplitHorizontal({domain = "CurrentPaneDomain"})
        },
        {
            key = "-",
            mods = "LEADER",
            action = wezterm.action.SplitVertical({domain = "CurrentPaneDomain"})
        },
        {
            key = "x",
            mods = "CTRL|SHIFT",
            action = wezterm.action.ActivateCopyMode
        }
    }
    -- Add keybindings for activating tabs
    for i = 1,8 do
        table.insert(config.keys, {
            key = tostring(i),
            mods = "LEADER",
            action = wezterm.action.ActivateTab(i - 1),
        })
    end
end

return module
