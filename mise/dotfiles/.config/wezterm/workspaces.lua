local wezterm = require("wezterm")

local module = {}

local function expand_home(path)
  if path:sub(1, 1) == "~" then
    return wezterm.home_dir .. path:sub(2)
  end

  return path
end

-- root は .gitconfig.tmpl の ghq.root が唯一の情報源。ここに複製せず実行時に引く。
-- GHQ_ROOT -> git config ghq.root -> ghq の既定値 ($HOME/ghq) の順に解決する。
-- 複数 root が設定されている場合は先頭のみを対象にする。
local function ghq_root()
  local env = os.getenv("GHQ_ROOT")

  if env and env ~= "" then
    return expand_home(env:match("^[^:;\n]+") or env)
  end

  -- GUI を Dock から起動した場合 PATH が最小構成になるため、mise 管理の ghq では
  -- なく macOS/Linux で常に PATH 上にある git から root を引く。
  local ok, stdout = wezterm.run_child_process({ "git", "config", "--get", "ghq.root" })

  if ok and stdout then
    local root = stdout:gsub("%s+$", "")

    if root ~= "" then
      return expand_home(root)
    end
  end

  return wezterm.home_dir .. "/ghq"
end

local function workspace_name(path)
  local owner, repo = path:match("([^/]+)/([^/]+)$")

  if owner and repo then
    return owner .. "/" .. repo
  end

  return (path:gsub(".*/", ""))
end

-- ghq のレイアウトは <root>/<host>/<owner>/<repo>。GitLab のサブグループなどで
-- 1 段深くなることがあるため 2 パターン glob し、.git を持つものだけ採用する。
local function projects()
  local root = ghq_root()
  local seen = {}
  local candidates = {}

  for _, depth in ipairs({ "*/*/*", "*/*/*/*" }) do
    local ok, matches = pcall(wezterm.glob, root .. "/" .. depth .. "/.git")

    if ok and matches then
      for _, git_path in ipairs(matches) do
        local repo = git_path:gsub("\\", "/"):gsub("/%.git$", "")

        if not seen[repo] then
          seen[repo] = true
          table.insert(candidates, repo)
        end
      end
    end
  end

  -- submodule も .git (file) を持つため深い方の glob に引っかかる。辞書順では
  -- 祖先が先に来るので、既に採用したリポジトリ配下のものは除外する。
  -- git worktree のように独立したパスにあるものは残る。
  table.sort(candidates)

  local entries = {}

  for _, repo in ipairs(candidates) do
    local nested = false

    for _, parent in ipairs(entries) do
      if repo:sub(1, #parent.id + 1) == parent.id .. "/" then
        nested = true
        break
      end
    end

    if not nested then
      table.insert(entries, {
        id = repo,
        label = repo:sub(#root + 2),
      })
    end
  end

  return entries, root
end

-- ghq 配下のリポジトリを選び、そのリポジトリを cwd とする workspace へ切り替える。
function module.ghq_selector()
  return wezterm.action_callback(function(window, pane)
    local entries, root = projects()

    if #entries == 0 then
      window:toast_notification("wezterm", "No ghq repositories under " .. root, nil, 4000)
      return
    end

    window:perform_action(
      wezterm.action.InputSelector({
        title = "ghq projects",
        description = "Select a repository to open as a workspace",
        fuzzy = true,
        fuzzy_description = "ghq> ",
        choices = entries,
        action = wezterm.action_callback(function(inner_window, inner_pane, id)
          if not id then
            return
          end

          inner_window:perform_action(
            wezterm.action.SwitchToWorkspace({
              name = workspace_name(id),
              spawn = { cwd = id },
            }),
            inner_pane
          )
        end),
      }),
      pane
    )
  end)
end

return module
