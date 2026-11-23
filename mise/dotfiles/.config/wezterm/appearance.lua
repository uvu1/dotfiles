local wezterm = require("wezterm")

local tab_bar_background = "#0b0e14"
local tab_colors = {
  active = { bg_color = "#7aa2f7", fg_color = "#0b0e14", intensity = "Bold" },
  inactive = { bg_color = "#151922", fg_color = "#a9b1d6" },
  hover = { bg_color = "#24283b", fg_color = "#c0caf5", italic = false },
}

local function format_tab_title(tab, _, _, _, hover, max_width)
  local colors = tab.is_active and tab_colors.active or (hover and tab_colors.hover or tab_colors.inactive)
  local title = tab.tab_title ~= "" and tab.tab_title or tab.active_pane.title
  local index = "  " .. (tab.tab_index + 1) .. " "
  local title_width = max_width - #index - 5
  if title_width < 1 then
    return wezterm.truncate_right(title, max_width)
  end

  return {
    { Background = { Color = tab_bar_background } },
    { Foreground = { Color = colors.bg_color } },
    { Text = "" },
    { Background = { Color = colors.bg_color } },
    { Foreground = { Color = colors.fg_color } },
    { Text = index .. wezterm.truncate_right(title, title_width) .. "  " },
    { Background = { Color = tab_bar_background } },
    { Foreground = { Color = colors.bg_color } },
    { Text = " " },
  }
end

local function apply(config, windows)
  wezterm.on("format-tab-title", format_tab_title)
  config.use_fancy_tab_bar = false
  config.tab_bar_at_bottom = false
  config.hide_tab_bar_if_only_one_tab = false
  config.show_new_tab_button_in_tab_bar = false
  config.show_close_tab_button_in_tabs = false
  config.tab_max_width = 32
  config.colors = {
    tab_bar = {
      background = tab_bar_background,
      inactive_tab_edge = "none",
      active_tab = tab_colors.active,
      inactive_tab = tab_colors.inactive,
      inactive_tab_hover = tab_colors.hover,
    },
  }

  config.initial_cols = 120
  config.initial_rows = 32
  config.font_size = windows and 14.0 or 18.0
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
