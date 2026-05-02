local wezterm = require("wezterm")
local appearance = require("appearance")
local keybinds = require("keybinds")

local config = wezterm.config_builder()

-- General configurations
config.automatically_reload_config = true
config.use_ime = true
config.mux_enable_ssh_agent = false

-- Set default shell based on the operating system
local osName = wezterm.target_triple
if string.find(osName, "windows") then
    config.default_prog = { "pwsh.exe", "-NoLogo" }
elseif string.find(osName, "darwin") then
    config.default_prog = { "/bin/zsh", "-l" }
elseif string.find(osName, "linux") then
    config.default_prog = { "/usr/bin/zsh", "-l" }
end

appearance.apply(config)
keybinds.apply(config)

return config
