local wezterm = require("wezterm")
local appearance = require("appearance")
local bell = require("bell")
local keybinds = require("keybinds")
local statusbar = require("statusbar")

local config = wezterm.config_builder()

-- General configurations
config.automatically_reload_config = true
config.use_ime = true
config.mux_enable_ssh_agent = false

config.native_macos_fullscreen_mode = true

-- Set default shell based on the operating system
local osName = wezterm.target_triple
if string.find(osName, "windows") then
  config.default_prog = { "pwsh.exe", "-NoLogo" }
elseif string.find(osName, "darwin") then
  config.default_prog = { "/bin/zsh", "-l" }
elseif string.find(osName, "linux") then
  config.default_prog = { "/usr/bin/zsh", "-l" }
end

-- mux server 上でタブ/ペインを保持し、GUI の再起動やクラッシュでセッションを失わない。
-- Windows は GUI の起動方法を変えたくないため対象外。
-- GUI と mux server のバージョンが食い違って接続できなくなった場合は
-- `wezterm cli kill-server` でサーバを落としてから起動し直す。
if not string.find(osName, "windows") then
  config.unix_domains = {
    { name = "unix" },
  }
  config.default_gui_startup_args = { "connect", "unix" }
end

appearance.apply(config)
bell.apply(config)
keybinds.apply(config)
statusbar.apply(config)

return config
