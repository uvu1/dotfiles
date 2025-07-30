local wezterm = require("wezterm")
local config = wezterm.config_builder()

config.automatically_reload_config = true
config.use_ime = true

local keybind = require("keybind")
keybind.apply_config(config)

local appearence = require("appearence")
appearence.apply_config(config)

config.mux_enable_ssh_agent = false

local os_name = wezterm.target_triple
if string.find(os_name, "darwin") then
    config.default_prog = { "/bin/zsh" }
    config.font_size = 14
elseif string.find(os_name, "linux") then
    config.default_prog = { "/usr/bin/zsh" }
elseif string.find(os_name, "windows") then
    config.default_prog = { "C:\\Program Files\\PowerShell\\7-preview\\pwsh.exe" }
end

return config
