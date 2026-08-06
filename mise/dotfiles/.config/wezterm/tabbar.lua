local wezterm = require("wezterm")
local bell = require("bell")

local module = {}

local EDGE_BG = "#0b0e14"

local BELL_BADGE = "󰂞 "
-- グリフ + 空白の表示幅。#BELL_BADGE はバイト長なので桁数の予約には使えない。
local BELL_BADGE_WIDTH = 2

local INDEX_LEFT_PAD = "  "
local INDEX_RIGHT_PAD = " "
local TITLE_LEFT_PAD = ""
local TITLE_RIGHT_PAD = "  "
local TAB_GAP = " "

local ACTIVE_BG = "#7aa2f7"
local ACTIVE_FG = "#0b0e14"

local INACTIVE_BG = "#151922"
local INACTIVE_FG = "#a9b1d6"

local HOVER_BG = "#24283b"
local HOVER_FG = "#c0caf5"

-- 同じものを指す別名を 1 つに寄せてから ICONS を引く。
local ALIASES = {
  powershell = "pwsh",
  wslhost = "wsl",
}

-- 正規化済みのプロセス名 -> グリフ。ここに無いものは DEFAULT_ICON で出す。
local ICONS = {
  ssh = "󰣀",
  pwsh = "",
  wsl = "󰌽",
  zsh = "",
}

local DEFAULT_ICON = ""

local function basename(s)
  return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

local function normalize_process_name(name)
  if not name or name == "" then
    return ""
  end

  name = basename(name)
  name = name:lower()
  name = name:gsub("%.exe$", "")

  return name
end

local function foreground_process_info(pane)
  local ok, info = pcall(function()
    return pane:get_foreground_process_info()
  end)

  if ok then
    return info
  end

  return nil
end

local ssh_options_with_arg = {
  ["-b"] = true,
  ["-c"] = true,
  ["-D"] = true,
  ["-E"] = true,
  ["-e"] = true,
  ["-F"] = true,
  ["-I"] = true,
  ["-i"] = true,
  ["-J"] = true,
  ["-L"] = true,
  ["-l"] = true,
  ["-m"] = true,
  ["-O"] = true,
  ["-o"] = true,
  ["-p"] = true,
  ["-Q"] = true,
  ["-R"] = true,
  ["-S"] = true,
  ["-W"] = true,
  ["-w"] = true,
}

local function ssh_host_from_argv(argv)
  if not argv or #argv == 0 then
    return nil
  end

  local i = 2

  while i <= #argv do
    local arg = argv[i]

    if arg == "--" then
      local host = argv[i + 1]
      if host then
        return host:gsub("^.-@", "")
      end
      return nil
    end

    if ssh_options_with_arg[arg] then
      i = i + 2
    elseif arg:match("^%-[bcDEeFIiJLlmOoPQRSWw].+") then
      i = i + 1
    elseif arg:sub(1, 1) == "-" then
      i = i + 1
    else
      local host = arg
      host = host:gsub("^.-@", "")
      host = host:gsub("^%[", ""):gsub("%]$", "")
      return host
    end
  end

  return nil
end

local function cwd_name(pane)
  local cwd = pane.current_working_dir and tostring(pane.current_working_dir) or ""

  if cwd == "" then
    return ""
  end

  cwd = cwd:gsub("^file://", "")
  cwd = cwd:gsub("%%20", " ")

  return basename(cwd)
end

-- mux 越しのペインは foreground process を報告しない。ClientPane は
-- get_foreground_process_name を実装しておらず、mux の codec も working_dir しか
-- 運ばないため、いずれも空になる。mux を越えて伝搬する user_vars を第一の情報源にし、
-- mux を経由しない起動のためにプロセス情報をフォールバックとして残す。
local function pane_argv(pane)
  local prog = pane.user_vars and pane.user_vars.WEZTERM_PROG

  if prog and prog ~= "" then
    local argv = {}

    for word in prog:gmatch("%S+") do
      table.insert(argv, word)
    end

    if #argv > 0 then
      return argv
    end
  end

  local info = foreground_process_info(pane)

  if info and info.argv and #info.argv > 0 then
    return info.argv
  end

  if pane.foreground_process_name and pane.foreground_process_name ~= "" then
    return { pane.foreground_process_name }
  end

  return nil
end

local function tab_title(tab)
  if tab.tab_title and #tab.tab_title > 0 then
    return tab.tab_title
  end

  local pane = tab.active_pane
  local argv = pane_argv(pane)
  local name = normalize_process_name(argv and argv[1])

  -- コマンドを実行していないペインはシェル自身を名乗らせる。WSL の zsh は
  -- WEZTERM_SHELL に wsl を入れるので、pwsh から開いたタブは従来どおり wsl と出る。
  if name == "" then
    name = normalize_process_name(pane.user_vars and pane.user_vars.WEZTERM_SHELL)
  end

  if name == "" then
    return pane.title
  end

  name = ALIASES[name] or name

  -- ssh は接続先が cwd より知りたい情報なので、そちらだけ差し替える。
  local detail

  if name == "ssh" then
    detail = ssh_host_from_argv(argv)
  else
    detail = cwd_name(pane)
  end

  local title = (ICONS[name] or DEFAULT_ICON) .. " " .. name

  if detail and detail ~= "" then
    return title .. " " .. detail
  end

  return title
end

-- bell が鳴ったタブに印を付ける。アクティブなタブは見えている扱いで印を消すので、
-- format-tab-title の再描画がそのまま既読処理になる。
local function bell_badge(tab)
  local badge = ""

  for _, pane in ipairs(tab.panes) do
    if tab.is_active then
      bell.clear(pane.pane_id)
    elseif bell.is_rung(pane.pane_id) then
      badge = BELL_BADGE
    end
  end

  return badge
end

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local title = tab_title(tab)
  local index = tostring(tab.tab_index + 1)
  local badge = bell_badge(tab)

  local reserved = 8 + (badge == "" and 0 or BELL_BADGE_WIDTH)

  if #title > max_width - reserved then
    title = wezterm.truncate_right(title, max_width - reserved - 1) .. "…"
  end

  local bg
  local fg

  if tab.is_active then
    bg = ACTIVE_BG
    fg = ACTIVE_FG
  elseif hover then
    bg = HOVER_BG
    fg = HOVER_FG
  else
    bg = INACTIVE_BG
    fg = INACTIVE_FG
  end

  return {
    { Background = { Color = EDGE_BG } },
    { Foreground = { Color = bg } },
    { Text = "" },

    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = INDEX_LEFT_PAD .. index .. INDEX_RIGHT_PAD },

    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = badge .. TITLE_LEFT_PAD .. title .. TITLE_RIGHT_PAD },

    { Background = { Color = EDGE_BG } },
    { Foreground = { Color = bg } },
    { Text = "" .. TAB_GAP },
  }
end)

function module.apply(config)
  config.use_fancy_tab_bar = false
  config.tab_bar_at_bottom = false
  config.hide_tab_bar_if_only_one_tab = false
  config.show_new_tab_button_in_tab_bar = false
  config.show_close_tab_button_in_tabs = false
  config.tab_max_width = 32

  config.colors = config.colors or {}

  config.window_frame = {
    inactive_titlebar_bg = "none",
    active_titlebar_bg = "none",
  }
  config.window_background_gradient = {
    colors = { "#000000" },
  }

  config.colors.tab_bar = {
    background = EDGE_BG,
    inactive_tab_edge = "none",
    active_tab = {
      bg_color = ACTIVE_BG,
      fg_color = ACTIVE_FG,
      intensity = "Bold",
    },
    inactive_tab = {
      bg_color = INACTIVE_BG,
      fg_color = INACTIVE_FG,
    },
    inactive_tab_hover = {
      bg_color = HOVER_BG,
      fg_color = HOVER_FG,
      italic = false,
    },
  }
end

return module
