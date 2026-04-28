local wezterm = require("wezterm")
local tabbar = require("tabbar")
local module = {}
local background = {}

-- Set background image based on the operating system
local osName = wezterm.target_triple
if string.find(osName, "windows") then
    background = {
        {
            source = {
                File = "C:\\Users\\uvu\\.config\\wezterm\\resources\\background.jpg",
            },
            opacity = 0.12,
            vertical_align = "Middle",
            horizontal_align = "Center",
        },
    }
elseif string.find(osName, "darwin") then
    background = {
        {
            source = { File = "/Users/uvu/.config/wezterm/resources/background.jpg" },
            opacity = 0.12,
            vertical_align = "Middle",
            horizontal_align = "Center",
        },
    }
end

function module.apply(config)
    -- window size
    config.initial_cols = 120
    config.initial_rows = 32

    -- font
    config.font_size = 12.0
    config.font = wezterm.font("JetBrains Mono", { weight = "Medium" })

    -- background
    config.window_background_opacity = 0.9
    config.text_background_opacity = 0.9
    config.macos_window_background_blur = 20
    config.win32_system_backdrop = "Acrylic"
    config.background = background

    -- content
    config.default_cursor_style = "SteadyBar"
    config.cursor_blink_rate = 500
    config.window_content_alignment = {
        horizontal = "Center",
        vertical = "Center",
    }

    -- tab
    tabbar.apply(config)

    -- window titlebar
    config.window_decorations = "RESIZE"
end

return module