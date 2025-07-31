local wezterm = require("wezterm")
local config = wezterm.config_builder()

local function file_exists(path)
   local f = io.open(path, "r")
   if f~=nil then io.close(f) return true else return false end
end

config.automatically_reload_config = true
config.use_ime = true

wezterm.on("gui-startup", function(cmd)
    local _, _, window = wezterm.mux.spawn_window(cmd or {})
    window:gui_window():maximize()
end)

local keybind = require("keybind")
keybind.apply_config(config)

local appearence = require("appearence")
appearence.apply_config(config)

config.mux_enable_ssh_agent = false
config.hide_tab_bar_if_only_one_tab = true

local os_name = wezterm.target_triple
if string.find(os_name, "darwin") then
    config.default_prog = { "/usr/bin/env zsh" }
    config.font_size = 14
elseif string.find(os_name, "linux") then
    config.default_prog = { "/usr/bin/env zsh" }
elseif string.find(os_name, "windows") then
    local pwsh_path = "C:\\Program Files\\PowerShell\\7-preview\\pwsh.exe"
    if file_exists(pwsh_path) then
        config.default_prog = { pwsh_path }
    else
        config.default_prog = { "C:\\WINDOWS\\system32\\cmd.exe" }
    end
end

return config
