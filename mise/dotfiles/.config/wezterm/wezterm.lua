local wezterm = require("wezterm")
local config = wezterm.config_builder()
local windows = wezterm.target_triple:find("windows") ~= nil
local macos = wezterm.target_triple:find("darwin") ~= nil

-- 対話 zsh で mise を有効にしてから Herdr を起動する。
local start_herdr = "command -v herdr >/dev/null && exec herdr; exec zsh -l"
if windows then
  -- wsl.exe --exec は Nix の zsh を PATH から見つけられない。
  config.default_prog = { "wsl.exe", "--cd", "~", "--exec", "/home/uvu1/.nix-profile/bin/zsh", "-lic", start_herdr }
  config.allow_win32_input_mode = false
elseif macos then
  config.default_prog = { "/bin/zsh", "-lic", start_herdr }
  config.send_composed_key_when_left_alt_is_pressed = false
  config.native_macos_fullscreen_mode = true
  config.window_decorations = "RESIZE"

  wezterm.on("gui-startup", function(cmd)
    local _, _, window = wezterm.mux.spawn_window(cmd or {})
    window:gui_window():toggle_fullscreen()
  end)
end

config.use_ime = true

-- Ctrl+Q、タブ・分割・ワークスペースの管理は Herdr が持つ。
config.enable_tab_bar = false
config.window_close_confirmation = "NeverPrompt"
local appearance = wezterm.config_dir .. "/appearance.lua"
local keybinds = wezterm.config_dir .. "/keybinds.lua"
wezterm.add_to_config_reload_watch_list(appearance)
wezterm.add_to_config_reload_watch_list(keybinds)
dofile(appearance)(config, windows)
dofile(keybinds)(config)

return config
