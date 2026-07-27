local wezterm = require("wezterm")

local module = {}

-- tabbar.lua と同じパレット。
local EDGE_BG = "#0b0e14"

local LEADER_BG = "#e0af68"
local LEADER_FG = "#0b0e14"

local KEY_TABLE_BG = "#f7768e"
local KEY_TABLE_FG = "#0b0e14"

local WORKSPACE_BG = "#151922"
local WORKSPACE_FG = "#a9b1d6"

local LEFT_EDGE = ""
local RIGHT_EDGE = ""

local function push_segment(elements, bg, fg, text)
  table.insert(elements, { Background = { Color = EDGE_BG } })
  table.insert(elements, { Foreground = { Color = bg } })
  table.insert(elements, { Text = LEFT_EDGE })

  table.insert(elements, { Background = { Color = bg } })
  table.insert(elements, { Foreground = { Color = fg } })
  table.insert(elements, { Text = text })

  table.insert(elements, { Background = { Color = EDGE_BG } })
  table.insert(elements, { Foreground = { Color = bg } })
  table.insert(elements, { Text = RIGHT_EDGE })
end

wezterm.on("update-status", function(window)
  local elements = {}

  if window:leader_is_active() then
    push_segment(elements, LEADER_BG, LEADER_FG, " 󰘴 LEADER ")
  end

  local key_table = window:active_key_table()

  if key_table then
    push_segment(elements, KEY_TABLE_BG, KEY_TABLE_FG, " 󰌌 " .. key_table .. " ")
  end

  push_segment(elements, WORKSPACE_BG, WORKSPACE_FG, "  " .. window:active_workspace() .. " ")

  window:set_right_status(wezterm.format(elements))
end)

function module.apply(config)
  -- update-status は status_update_interval 周期でしか発火せず、LEADER や
  -- key table の状態変化では発火しない。既定の 1000ms では LEADER
  -- (timeout 2500ms) の表示が間に合わないため短くする。
  config.status_update_interval = 300
end

return module
