local M = {}

local uv = vim.uv or vim.loop

local colors = {
  text = "#353042",
  active = "#FFA7C4",
  title = "#ea7599",
  inactive = "#857282",
  inactive_text = "#fff5fb",
  transparent = "none",
}

local ai_requests = {}
local ai_timer = nil
local branch_cache = {}

local function refresh_statusline()
  pcall(function()
    require("lualine").refresh({
      place = { "statusline" },
    })
  end)
end

local function target_win()
  local win = tonumber(vim.g.statusline_winid)

  if win and vim.api.nvim_win_is_valid(win) then
    return win
  end

  return vim.api.nvim_get_current_win()
end

local function target_buf()
  local win = target_win()

  if win and vim.api.nvim_win_is_valid(win) then
    return vim.api.nvim_win_get_buf(win)
  end

  return vim.api.nvim_get_current_buf()
end

local function pane_kind()
  local buf = target_buf()
  local ok, kind = pcall(require, "pane-tabs.buffers.kind")

  if ok then
    if kind.is_explorer(buf) then
      return "explorer"
    end

    if kind.is_ai(buf) then
      return "ai"
    end

    if kind.is_editor(buf) then
      return "editor"
    end
  end

  return "other"
end

local function is_codecompanion_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "codecompanion"
end

local function now()
  return uv.now()
end

local function format_elapsed(ms)
  local seconds = math.max(0, math.floor(ms / 1000))

  if seconds < 60 then
    return seconds .. "s"
  end

  local minutes = math.floor(seconds / 60)
  local rest = seconds % 60

  if minutes < 60 then
    return ("%dm%02ds"):format(minutes, rest)
  end

  return ("%dh%02dm"):format(math.floor(minutes / 60), minutes % 60)
end

local function any_ai_request_running()
  for _, request in pairs(ai_requests) do
    if request.running then
      return true
    end
  end

  return false
end

local function ensure_ai_timer()
  if ai_timer then
    return
  end

  ai_timer = uv.new_timer()
  ai_timer:start(1000, 1000, vim.schedule_wrap(function()
    refresh_statusline()

    if any_ai_request_running() then
      return
    end

    ai_timer:stop()
    ai_timer:close()
    ai_timer = nil
  end))
end

local function request_buf(args)
  local data = args.data or {}
  local bufnr = data.bufnr or data.buf or args.buf

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return nil
  end

  if data.interaction and data.interaction ~= "chat" then
    return nil
  end

  if data.interaction == "chat" or is_codecompanion_buf(bufnr) then
    return bufnr
  end

  return nil
end

local function start_ai_request(buf)
  if ai_requests[buf] and ai_requests[buf].running then
    return
  end

  ai_requests[buf] = {
    started_at = now(),
    finished_at = nil,
    running = true,
  }

  ensure_ai_timer()
  refresh_statusline()
end

local function finish_ai_request(buf)
  local request = ai_requests[buf]

  if not request then
    return
  end

  request.finished_at = now()
  request.running = false
  refresh_statusline()
end

local function setup_ai_request_autocmds()
  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("LualinePaneAIRequests", { clear = true }),
    pattern = {
      "CodeCompanionChatSubmitted",
      "CodeCompanionChatDone",
      "CodeCompanionChatStopped",
      "CodeCompanionChatClosed",
      "CodeCompanionRequestStarted",
      "CodeCompanionRequestFinished",
    },
    callback = function(args)
      local buf = request_buf(args)

      if not buf then
        return
      end

      if args.match == "CodeCompanionChatSubmitted" or args.match == "CodeCompanionRequestStarted" then
        start_ai_request(buf)
        return
      end

      if args.match == "CodeCompanionChatClosed" then
        ai_requests[buf] = nil
        refresh_statusline()
        return
      end

      finish_ai_request(buf)
    end,
  })
end

local function setup_refresh_autocmds()
  vim.api.nvim_create_autocmd({
    "BufWinEnter",
    "DiagnosticChanged",
    "WinClosed",
    "WinNew",
    "WinResized",
  }, {
    group = vim.api.nvim_create_augroup("LualinePaneRefresh", { clear = true }),
    callback = refresh_statusline,
  })
end

local function pane_cond(kind)
  return function()
    return pane_kind() == kind
  end
end

local function pill(component, opts)
  opts = opts or {}

  return vim.tbl_extend("force", {
    component,
    separator = { left = "", right = "" },
    padding = { left = 1, right = 1 },
  }, opts)
end

local function explorer_picker_for_win(win)
  local ok, snacks = pcall(require, "snacks")

  if not ok or not snacks.picker then
    return nil
  end

  local pickers = snacks.picker.get({
    source = "explorer",
    tab = false,
  })

  for _, picker in ipairs(pickers or {}) do
    local wins = {
      picker.input and picker.input.win and picker.input.win.win,
      picker.list and picker.list.win and picker.list.win.win,
      picker.preview and picker.preview.win and picker.preview.win.win,
    }

    for _, picker_win in pairs(wins) do
      if picker_win == win then
        return picker
      end
    end
  end

  return pickers and pickers[1] or nil
end

local function dirname(path)
  if vim.fs and vim.fs.dirname then
    return vim.fs.dirname(path)
  end

  return vim.fn.fnamemodify(path, ":h")
end

local function find_git_root(path)
  if not path or path == "" then
    return nil
  end

  if not (vim.fs and vim.fs.find) then
    return nil
  end

  local git = vim.fs.find(".git", {
    upward = true,
    path = path,
  })[1]

  return git and dirname(git) or nil
end

local function cached_git_branch(root)
  local cached = branch_cache[root]

  if cached and now() - cached.checked_at < 5000 then
    return cached.branch
  end

  local branch = vim.fn.systemlist({ "git", "-C", root, "branch", "--show-current" })[1] or ""

  if vim.v.shell_error ~= 0 or branch == "" then
    branch = vim.fn.systemlist({ "git", "-C", root, "rev-parse", "--short", "HEAD" })[1] or ""
  end

  if vim.v.shell_error ~= 0 then
    branch = ""
  end

  branch_cache[root] = {
    branch = branch,
    checked_at = now(),
  }

  return branch
end

local function current_git_branch()
  local buf = target_buf()
  local branch = vim.b[buf].gitsigns_head

  if branch and branch ~= "" then
    return " " .. branch
  end

  local name = vim.api.nvim_buf_get_name(buf)
  local root = find_git_root(name ~= "" and dirname(name) or uv.cwd())

  if root then
    branch = cached_git_branch(root)

    if branch ~= "" then
      return " " .. branch
    end
  end

  return ""
end

local function diagnostics_count()
  local counts = {
    [vim.diagnostic.severity.ERROR] = 0,
    [vim.diagnostic.severity.WARN] = 0,
    [vim.diagnostic.severity.INFO] = 0,
    [vim.diagnostic.severity.HINT] = 0,
  }

  for _, diagnostic in ipairs(vim.diagnostic.get(target_buf())) do
    counts[diagnostic.severity] = (counts[diagnostic.severity] or 0) + 1
  end

  local total = counts[vim.diagnostic.severity.ERROR]
    + counts[vim.diagnostic.severity.WARN]
    + counts[vim.diagnostic.severity.INFO]
    + counts[vim.diagnostic.severity.HINT]

  if total == 0 then
    return "󰒡 0"
  end

  local parts = {}

  if counts[vim.diagnostic.severity.ERROR] > 0 then
    table.insert(parts, " " .. counts[vim.diagnostic.severity.ERROR])
  end

  if counts[vim.diagnostic.severity.WARN] > 0 then
    table.insert(parts, " " .. counts[vim.diagnostic.severity.WARN])
  end

  if counts[vim.diagnostic.severity.INFO] > 0 then
    table.insert(parts, " " .. counts[vim.diagnostic.severity.INFO])
  end

  if counts[vim.diagnostic.severity.HINT] > 0 then
    table.insert(parts, "󰌵 " .. counts[vim.diagnostic.severity.HINT])
  end

  return table.concat(parts, " ")
end

local function language()
  local buf = target_buf()
  local ft = vim.bo[buf].filetype

  if ft == "" then
    ft = "text"
  end

  local ok, devicons = pcall(require, "nvim-web-devicons")
  local icon = ok and devicons.get_icon_by_filetype(ft, { default = true }) or nil

  return (icon or "󰈙") .. " " .. ft
end

-- ExplorerPane: show the current Snacks explorer file count.
function M.explorer_files()
  local picker = explorer_picker_for_win(target_win())
  local count = 0

  if picker then
    count = picker.list and picker.list.count and picker.list:count() or picker:count()
  end

  if count == 0 then
    count = vim.api.nvim_buf_line_count(target_buf())
  end

  return "󰈔 " .. count
end

-- EditorPane: show git branch, LSP diagnostics count, and language.
function M.editor_branch()
  return current_git_branch()
end

function M.editor_diagnostics()
  return diagnostics_count()
end

function M.editor_language()
  return language()
end

-- AIPane: show elapsed time since the current CodeCompanion request was sent.
function M.ai_elapsed()
  local request = ai_requests[target_buf()]

  if not request then
    return "󰚩 idle"
  end

  local elapsed_to = request.running and now() or request.finished_at or now()

  return "󰚩 " .. format_elapsed(elapsed_to - request.started_at)
end

function M.ai_elapsed_color()
  local request = ai_requests[target_buf()]

  if request and request.running then
    return { fg = colors.text, bg = colors.active, gui = "bold" }
  end

  return { fg = colors.inactive_text, bg = colors.inactive }
end

function M.sections()
  return {
    lualine_a = {
      pill(M.explorer_files, {
        cond = pane_cond("explorer"),
        color = { fg = colors.text, bg = colors.active, gui = "bold" },
      }),
      pill(M.editor_branch, {
        cond = pane_cond("editor"),
        color = { fg = colors.text, bg = colors.active, gui = "bold" },
      }),
      pill(M.editor_diagnostics, {
        cond = pane_cond("editor"),
        color = { fg = colors.inactive_text, bg = colors.inactive },
      }),
      pill(M.editor_language, {
        cond = pane_cond("editor"),
        color = { fg = colors.text, bg = colors.title, gui = "bold" },
      }),
      pill(M.ai_elapsed, {
        cond = pane_cond("ai"),
        color = M.ai_elapsed_color,
      }),
    },
    lualine_b = {},
    lualine_c = {},
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  }
end

function M.theme()
  local function section()
    return { fg = colors.inactive, bg = colors.transparent }
  end

  return {
    normal = { a = section(), b = section(), c = section(), x = section(), y = section(), z = section() },
    insert = { a = section(), b = section(), c = section(), x = section(), y = section(), z = section() },
    visual = { a = section(), b = section(), c = section(), x = section(), y = section(), z = section() },
    replace = { a = section(), b = section(), c = section(), x = section(), y = section(), z = section() },
    command = { a = section(), b = section(), c = section(), x = section(), y = section(), z = section() },
    inactive = { a = section(), b = section(), c = section(), x = section(), y = section(), z = section() },
  }
end

function M.setup()
  setup_ai_request_autocmds()
  setup_refresh_autocmds()
end

return M
