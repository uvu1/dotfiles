local wezterm = require("wezterm")

local module = {}

-- claude / codex は完了と承認待ちで BEL を鳴らすところまでしか設定できない
-- (claude は preferredNotifChannel、codex は tui.notification_method)。
-- 「どう知らせるか」の判断はこのモジュールに一本化する。
-- 鳴ったペインは pane_id で覚えておき、tabbar がタブのバッジ表示に使う。
local rung = {}

function module.is_rung(pane_id)
  return rung[pane_id] == true
end

function module.clear(pane_id)
  rung[pane_id] = nil
end

-- pane:tab() は debug overlay のように mux 管理外のペインで nil を返すため、
-- workspace 名が引けないケースはタイトルだけにフォールバックする。
local function pane_label(pane)
  local title = pane:get_title()

  local ok, workspace = pcall(function()
    return pane:tab():window():get_workspace()
  end)

  if ok and workspace and workspace ~= "" then
    return workspace .. ": " .. title
  end

  return title
end

wezterm.on("bell", function(window, pane)
  local pane_id = pane:pane_id()

  -- 目の前のペインで鳴っただけなら画面を見れば分かるので何もしない。
  if window:is_focused() and window:active_pane():pane_id() == pane_id then
    return
  end

  rung[pane_id] = true
  window:toast_notification("WezTerm", pane_label(pane), nil, 4000)
end)

function module.apply(config)
  -- 通知はトーストとタブのバッジに寄せる。SystemBeep は macOS / WSL どちらでも
  -- 音だけ鳴って発生元が分からないため止める。audible_bell の設定に関係なく
  -- bell イベントは発火する。
  config.audible_bell = "Disabled"
end

return module
