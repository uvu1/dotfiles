local wezterm = require("wezterm")
local config = wezterm.config_builder()
local windows = wezterm.target_triple:find("windows") ~= nil
local macos = wezterm.target_triple:find("darwin") ~= nil
local shell

if windows then
  -- wsl.exe --exec は Nix の zsh を PATH から見つけられない。
  shell = { "wsl.exe", "--cd", "~", "--exec", "/home/uvu1/.nix-profile/bin/zsh", "-il" }
  config.allow_win32_input_mode = false
elseif macos then
  shell = { "/bin/zsh", "-il" }
  config.send_composed_key_when_left_alt_is_pressed = false
  config.native_macos_fullscreen_mode = true
end

if shell then
  config.default_prog = shell
  wezterm.on("gui-startup", function(cmd)
    cmd = cmd or {}
    if not cmd.args then
      -- ログインシェルで mise を有効化し、Herdr から離れたらシェルに戻る。
      cmd.args = { table.unpack(shell) }
      table.insert(cmd.args, "-c")
      table.insert(cmd.args, [[herdr; exec "$0" -il]])
    end
    local _, _, window = wezterm.mux.spawn_window(cmd)
    if macos then
      window:gui_window():toggle_fullscreen()
    end
  end)
end

config.use_ime = true
config.window_decorations = "RESIZE"

config.enable_tab_bar = true
config.window_close_confirmation = "NeverPrompt"
local appearance = wezterm.config_dir .. "/appearance.lua"
local keybinds = wezterm.config_dir .. "/keybinds.lua"
wezterm.add_to_config_reload_watch_list(appearance)
wezterm.add_to_config_reload_watch_list(keybinds)
dofile(appearance)(config, windows)
dofile(keybinds)(config)

return config
