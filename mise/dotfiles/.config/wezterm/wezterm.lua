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
-- Windows でも既定のペインは WSL にする。wsl_domains + default_domain は使えない:
-- 後述の default_gui_startup_args により最初のウィンドウが unix ドメインで開くので
-- default_domain が効かず、WSL ドメインのペインは GUI プロセス側のローカル所有になって
-- mux によるセッション永続化が壊れる。mux server を WSL 内で動かす構成は WSL 1 専用
-- (WSL 2 は AF_UNIX interop 非対応)。Windows 側プロセスである mux server が spawn する
-- default_prog 自体を wsl.exe にすれば、永続化を保ったまま WSL の login shell が起きる。
-- pwsh は launch_menu から開く (LEADER n)。SpawnCommand の domain 既定値は
-- CurrentPaneDomain = mux server なので、pwsh のタブも GUI 再起動で消えない。
local osName = wezterm.target_triple
if string.find(osName, "windows") then
  config.default_prog = { "wsl.exe", "~" }
  config.launch_menu = {
    { label = "pwsh", args = { "pwsh.exe", "-NoLogo" } },
  }
elseif string.find(osName, "darwin") then
  config.default_prog = { "/bin/zsh", "-l" }
elseif string.find(osName, "linux") then
  config.default_prog = { "/usr/bin/zsh", "-l" }
end

-- mux server 上でタブ/ペインを保持し、GUI の再起動やクラッシュでセッションを失わない。
-- default_gui_startup_args はサブコマンドなしで wezterm / wezterm-gui を起動したときに
-- 効くため、Windows のショートカットから wezterm-gui.exe を叩く起動方法のままで有効になる。
-- mux server が死ぬ（OS 再起動 / kill-server）とセッションも消える点は変わらない。
-- GUI と mux server のバージョンが食い違って接続できなくなった場合は
-- `wezterm cli kill-server` でサーバを落としてから起動し直す。
-- なお mux 越しのペインは foreground process を報告しないため、タブ名は user_vars に
-- 依存する。tabbar.lua と、それを publish する zsh/wezterm.zsh・PowerShell の
-- 50-wezterm.ps1 は三点セットで扱うこと。
config.unix_domains = {
  { name = "unix" },
}
config.default_gui_startup_args = { "connect", "unix" }

appearance.apply(config)
bell.apply(config)
keybinds.apply(config)
statusbar.apply(config)

return config
