local wezterm = require("wezterm")
local workspaces = require("workspaces")
local module = {}

local is_windows = wezterm.target_triple:find("windows") ~= nil

local function url_decode(s)
  return (s:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end))
end

-- Windows の既定ペインは mux server が spawn する wsl.exe。Windows 側の wezterm は
-- OSC 7 で受け取った Linux パスへ chdir できないため、SpawnCommand の cwd ではなく
-- wsl.exe --cd で引き継ぐ (wezterm 本体の WslDomain も内部で同じ引数を組んでいる)。
-- cwd を publish しているのは zsh/wezterm.zsh の OSC 7 なので、両者は対で扱うこと。
local function spawn_in_current_cwd(pane)
  local spawn = { domain = "CurrentPaneDomain" }

  if not is_windows then
    return spawn
  end

  -- pwsh ペイン (LEADER n) は Windows ローカルなので既定の cwd 継承がそのまま効く。
  if pane:get_user_vars().WEZTERM_SHELL ~= "wsl" then
    return spawn
  end

  local cwd = pane:get_current_working_dir()

  if not cwd or cwd.scheme ~= "file" then
    return spawn
  end

  spawn.args = { "wsl.exe", "--cd", url_decode(cwd.path) }

  return spawn
end

-- wezterm.action.X は引数を取るアクションでは呼び出し可能オブジェクトなので、
-- 変数に束縛せず実行時に名前で引く。
local function spawn_action(name)
  return wezterm.action_callback(function(window, pane)
    window:perform_action(wezterm.action[name](spawn_in_current_cwd(pane)), pane)
  end)
end

function module.apply(config)
  config.disable_default_key_bindings = true

  config.leader = {
    key = "q",
    mods = "CTRL",
    timeout_milliseconds = 2500,
  }

  config.quick_select_patterns = {
    -- Git SHA
    [[\b[0-9a-f]{7,40}\b]],

    -- GitHub owner/repo#123
    [[\b[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+#[0-9]+\b]],

    -- GitHub issue/PR URL-ish
    [[\bissues/[0-9]+\b]],
    [[\bpull/[0-9]+\b]],

    -- Kubernetes namespace/name
    [[\b[A-Za-z0-9-]+/[A-Za-z0-9_.-]+\b]],

    -- Kubernetes pod-ish
    [[\b[a-z0-9]([-a-z0-9]*[a-z0-9])?-[a-z0-9]{8,10}-[a-z0-9]{5}\b]],

    -- IPv4:port
    [[\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{2,5}\b]],

    -- domain
    [[\b[a-zA-Z0-9.-]+\.(?:dev|local|me|com|net|org|io|jp)\b]],

    -- file:line
    [[[\w./~_-]+:\d+]],

    -- windows path
    [[\b[A-Za-z]:\\[^\s:*?"<>|]+\b]],

    -- email
    [[\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]+\b]],
  }

  -- リサイズはモーダルにして CTRL|SHIFT+hjkl を解放する。one_shot = false なので
  -- table に入ったあとは hjkl の連打で調整でき、Escape / CTRL-g で抜ける。
  config.key_tables = {
    resize_pane = {
      { key = "h", action = wezterm.action.AdjustPaneSize({ "Left", 3 }) },
      { key = "l", action = wezterm.action.AdjustPaneSize({ "Right", 3 }) },
      { key = "j", action = wezterm.action.AdjustPaneSize({ "Down", 3 }) },
      { key = "k", action = wezterm.action.AdjustPaneSize({ "Up", 3 }) },
      { key = "Escape", action = "PopKeyTable" },
      { key = "g", mods = "CTRL", action = "PopKeyTable" },
    },
  }

  config.keys = {
    -- wezterm features
    { key = "p", mods = "CTRL|SHIFT", action = wezterm.action.ActivateCommandPalette },
    { key = "x", mods = "CTRL|SHIFT", action = wezterm.action.ActivateCopyMode },
    { key = "Space", mods = "CTRL|SHIFT", action = wezterm.action.QuickSelect },
    -- key passthrough
    -- Windows では allow_win32_input_mode が優先されるため Shift+Enter が素の CR として届き、
    -- Claude Code や nvim :terminal では改行ではなく送信になってしまう。Claude Code が組み込みで
    -- 改行として扱う ESC+CR（Alt+Enter）へ差し替える。生バイト送出なのでキーエンコードに左右されず、
    -- nvim 内蔵ターミナルも無改変で通過する。zsh では ^[^M が self-insert-unmeta なので改行挿入になる。
    { key = "Enter", mods = "SHIFT", action = wezterm.action.SendString("\x1b\r") },
    -- copy/paste
    { key = "c", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("Clipboard") },
    { key = "v", mods = "CTRL|SHIFT", action = wezterm.action.PasteFrom("Clipboard") },
    -- pane
    { key = "z", mods = "LEADER", action = wezterm.action.TogglePaneZoomState },
    { key = "h", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Left") },
    { key = "l", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Right") },
    { key = "j", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Down") },
    { key = "k", mods = "LEADER", action = wezterm.action.ActivatePaneDirection("Up") },
    { key = "/", mods = "LEADER", action = spawn_action("SplitHorizontal") },
    { key = "-", mods = "LEADER", action = spawn_action("SplitVertical") },
    { key = "x", mods = "LEADER", action = wezterm.action.CloseCurrentPane({ confirm = false }) },
    -- ペインが 3 枚以上になると hjkl の方向指定では狙えないためラベル選択する。
    { key = "Space", mods = "LEADER", action = wezterm.action.PaneSelect },
    { key = "s", mods = "LEADER", action = wezterm.action.PaneSelect({ mode = "SwapWithActive" }) },
    {
      key = "r",
      mods = "LEADER",
      action = wezterm.action.ActivateKeyTable({
        name = "resize_pane",
        one_shot = false,
        timeout_milliseconds = 2000,
      }),
    },
    -- workspace
    { key = "w", mods = "LEADER", action = wezterm.action.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
    {
      key = "W",
      mods = "LEADER",
      action = wezterm.action.PromptInputLine({
        description = "New workspace name",
        action = wezterm.action_callback(function(window, pane, line)
          if line and line ~= "" then
            window:perform_action(wezterm.action.SwitchToWorkspace({ name = line }), pane)
          end
        end),
      }),
    },
    -- zsh 側の ghq-fzf (bindkey ^g) と同じ操作感で workspace を開く。
    { key = "g", mods = "LEADER", action = workspaces.ghq_selector() },
    { key = "[", mods = "LEADER", action = wezterm.action.SwitchWorkspaceRelative(-1) },
    { key = "]", mods = "LEADER", action = wezterm.action.SwitchWorkspaceRelative(1) },
    -- tab
    -- SpawnTab は SpawnCommand を受け取れないので、cwd/args を渡せる方を使う。
    { key = "t", mods = "CTRL|SHIFT", action = spawn_action("SpawnCommandInNewTab") },
    -- CTRL|SHIFT t は既定のシェルで開く。別のシェルが要るときは launch_menu から選ぶ
    -- (Windows は既定が WSL なので、pwsh のタブはここから開く)。
    { key = "n", mods = "LEADER", action = wezterm.action.ShowLauncherArgs({ flags = "FUZZY|LAUNCH_MENU_ITEMS" }) },
    { key = "w", mods = "CTRL|SHIFT", action = wezterm.action.CloseCurrentTab({ confirm = false }) },
    -- quit
    { key = "q", mods = "LEADER|CTRL", action = wezterm.action.QuitApplication },
  }

  config.mouse_bindings = {
    -- 左ドラッグで選択を確定した時点でクリップボードへコピー(リンクならクリックで開く)
    {
      event = { Up = { streak = 1, button = "Left" } },
      mods = "NONE",
      action = wezterm.action.CompleteSelectionOrOpenLinkAtMouseCursor("ClipboardAndPrimarySelection"),
    },
    -- 右クリックでクリップボードからペースト
    {
      event = { Down = { streak = 1, button = "Right" } },
      mods = "NONE",
      action = wezterm.action.PasteFrom("Clipboard"),
    },
  }

  -- switch to tab 1-8 with leader + number
  for i = 1, 8 do
    table.insert(config.keys, {
      key = tostring(i),
      mods = "CTRL",
      action = wezterm.action.ActivateTab(i - 1),
    })
  end
end

return module
