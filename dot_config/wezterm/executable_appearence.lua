local module = {}

function module.apply_config(config)
    config.color_scheme = 'Catppuccin Macchiato'
    config.window_background_opacity = 0.83
    config.window_content_alignment = {
        horizontal = "Center",
        vertical = "Center",
    }
    config.window_decorations = "RESIZE"
    config.use_fancy_tab_bar = false
    config.show_new_tab_button_in_tab_bar = false
    config.window_frame = {
        inactive_titlebar_bg = "none",
        active_titlebar_bg = "none",
    }
    config.win32_system_backdrop = "Acrylic"
    config.macos_window_background_blur = 20
end

return module
