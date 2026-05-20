local ai = require("config.lualine_pane.ai")
local clock = require("config.lualine_pane.clock")
local pane = require("config.lualine_pane.pane")
local project = require("config.lualine_pane.project")
local runtime = require("config.lualine_pane.runtime")
local state = require("config.lualine_pane.state")
local weather = require("config.lualine_pane.weather")

local M = {}

local function diagnostics_count()
  local counts = {
    [vim.diagnostic.severity.ERROR] = 0,
    [vim.diagnostic.severity.WARN] = 0,
    [vim.diagnostic.severity.INFO] = 0,
    [vim.diagnostic.severity.HINT] = 0,
  }

  local root = project.root()

  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and project.buffer_in_project(buf, root) then
      for _, diagnostic in ipairs(vim.diagnostic.get(buf)) do
        counts[diagnostic.severity] = (counts[diagnostic.severity] or 0) + 1
      end
    end
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
  local buf = pane.target_buf()
  local ft = vim.bo[buf].filetype

  if ft == "" then
    ft = "text"
  end

  local ok, devicons = pcall(require, "nvim-web-devicons")
  local icon = ok and devicons.get_icon_by_filetype(ft, { default = true }) or nil
  local version = runtime.version(ft)

  return (icon or "󰈙") .. " " .. ft .. (version ~= "" and " " .. version or "")
end

local function cursor_position()
  local win = pane.target_win()

  if not win or not vim.api.nvim_win_is_valid(win) then
    return ""
  end

  local pos = vim.api.nvim_win_get_cursor(win)

  return ("Ln%d, Col%d"):format(pos[1], pos[2] + 1)
end

local function indent_width()
  local buf = pane.target_buf()
  local width = vim.bo[buf].shiftwidth

  if width == 0 then
    width = vim.bo[buf].tabstop
  end

  return "󰌒 " .. (vim.bo[buf].expandtab and "Space " or "Tab ") .. width
end

local function file_encoding()
  local buf = pane.target_buf()
  local encoding = vim.bo[buf].fileencoding

  if encoding == "" then
    encoding = vim.o.encoding
  end

  return "󰉿 " .. encoding:upper()
end

local function line_ending()
  local buf = pane.target_buf()
  local formats = {
    unix = "LF",
    dos = "CRLF",
    mac = "CR",
  }

  return "󰌑 " .. (formats[vim.bo[buf].fileformat] or vim.bo[buf].fileformat:upper())
end

local function current_mode()
  local raw = vim.fn.mode(1)
  local modes = {
    n = { icon = "󰌌", label = "NORMAL" },
    no = { icon = "󰌌", label = "O-PENDING" },
    nov = { icon = "󰌌", label = "O-PENDING" },
    noV = { icon = "󰌌", label = "O-PENDING" },
    noCTRLV = { icon = "󰌌", label = "O-PENDING" },
    niI = { icon = "󰌌", label = "NORMAL" },
    niR = { icon = "󰌌", label = "NORMAL" },
    niV = { icon = "󰌌", label = "NORMAL" },
    i = { icon = "󰏫", label = "INSERT" },
    ic = { icon = "󰏫", label = "INSERT" },
    ix = { icon = "󰏫", label = "INSERT" },
    v = { icon = "󰈈", label = "VISUAL" },
    V = { icon = "󰈈", label = "V-LINE" },
    ["\22"] = { icon = "󰈈", label = "V-BLOCK" },
    s = { icon = "󰒉", label = "SELECT" },
    S = { icon = "󰒉", label = "S-LINE" },
    ["\19"] = { icon = "󰒉", label = "S-BLOCK" },
    R = { icon = "󰛔", label = "REPLACE" },
    Rc = { icon = "󰛔", label = "REPLACE" },
    Rx = { icon = "󰛔", label = "REPLACE" },
    Rv = { icon = "󰛔", label = "V-REPLACE" },
    c = { icon = "", label = "COMMAND" },
    cv = { icon = "", label = "EX" },
    ce = { icon = "", label = "EX" },
    r = { icon = "󰆐", label = "PROMPT" },
    rm = { icon = "󰆐", label = "MORE" },
    ["r?"] = { icon = "󰆐", label = "CONFIRM" },
    t = { icon = "", label = "TERMINAL" },
    ["!"] = { icon = "", label = "SHELL" },
  }
  local mode = modes[raw] or modes[raw:sub(1, 1)] or { icon = "󰘳", label = raw:upper() }

  return mode.icon .. " " .. mode.label
end

local function current_mode_color()
  local raw = vim.fn.mode(1)
  local key = raw:sub(1, 1)
  local backgrounds = {
    n = state.colors.title,
    i = "#9ED072",
    v = "#B69CF6",
    V = "#B69CF6",
    ["\22"] = "#B69CF6",
    s = "#F8BD96",
    S = "#F8BD96",
    ["\19"] = "#F8BD96",
    R = "#F28FAD",
    r = "#F28FAD",
    c = "#89DCEB",
    t = "#A6E3A1",
    ["!"] = "#A6E3A1",
  }

  return { fg = state.colors.text, bg = backgrounds[key] or state.colors.active, gui = "bold" }
end

function M.explorer_files()
  local picker = pane.explorer_picker_for_win(pane.target_win())
  local count = 0

  if picker then
    count = picker.list and picker.list.count and picker.list:count() or picker:count()
  end

  if count == 0 then
    count = vim.api.nvim_buf_line_count(pane.target_buf())
  end

  return "󰈔 " .. count
end

function M.editor_diagnostics()
  return diagnostics_count()
end

function M.editor_os()
  return runtime.os_info()
end

function M.editor_language()
  return language()
end

function M.editor_position()
  return cursor_position()
end

function M.editor_indent()
  return indent_width()
end

function M.editor_encoding()
  return file_encoding()
end

function M.editor_line_ending()
  return line_ending()
end

function M.editor_time()
  return clock.current_time()
end

function M.editor_weather()
  return weather.current()
end

function M.focused_mode()
  return current_mode()
end

function M.focused_mode_color()
  return current_mode_color()
end

function M.ai_elapsed()
  return ai.elapsed()
end

function M.ai_elapsed_color()
  return ai.elapsed_color()
end

function M.ai_has_model()
  return ai.has_model()
end

function M.ai_model()
  return ai.model()
end

function M.ai_is_codex()
  return ai.is_codex()
end

function M.ai_has_thinking_level()
  return ai.has_thinking_level()
end

function M.ai_thinking_level()
  return ai.thinking_level()
end

function M.ai_has_context_usage()
  return ai.has_context_usage()
end

function M.ai_context_usage()
  return ai.context_usage()
end

function M.ai_context_usage_color()
  return ai.context_usage_color()
end

return M
