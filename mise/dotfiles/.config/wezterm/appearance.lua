local wezterm = require("wezterm")

local function apply(config, windows)
  config.initial_cols = 120
  config.initial_rows = 32
  config.font_size = 14.0
  config.font = wezterm.font_with_fallback({
    { family = "JetBrains Mono", weight = "Medium" },
    windows and { family = "Hiragino Maru Gothic ProN" } or { family = "Hiragino Sans", weight = "Medium" },
  })
  config.text_background_opacity = 0.9
  config.macos_window_background_blur = 20
  config.background = {
    -- 暗い下地に画像を重ね、文字のコントラストを確保する。
    {
      source = { Color = "#121212" },
      width = "100%",
      height = "100%",
      opacity = windows and 0.99 or 0.9,
    },
    {
      source = { File = wezterm.config_dir .. "/resources/background.jpg" },
      opacity = 0.12,
      vertical_align = "Middle",
      horizontal_align = "Center",
    },
  }
  config.default_cursor_style = "SteadyBar"
  config.window_content_alignment = { horizontal = "Center", vertical = "Center" }
end

return apply
