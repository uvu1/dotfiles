-- 組込コンポーネントで表せない集計・補足情報だけを保持する。
local pane = require("statusline.pane")
local project = require("statusline.project")
local runtime = require("statusline.runtime")
local M = {}

function M.diagnostics()
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

function M.language(ft)
  ft = ft ~= "" and ft or "text"
  local version = runtime.version(ft, pane.target_buf())
  return ft .. (version ~= "" and " " .. version or "")
end

-- 列番号は現行どおりバイト位置。日本語を含む行でも意味を変えない。
function M.position()
  local pos = vim.api.nvim_win_get_cursor(pane.target_win())
  return ("Ln%d, Col%d"):format(pos[1], pos[2] + 1)
end

function M.indent()
  local buf = pane.target_buf()
  local width = vim.bo[buf].shiftwidth
  if width == 0 then
    width = vim.bo[buf].tabstop
  end
  return "󰌒 " .. (vim.bo[buf].expandtab and "Space " or "Tab ") .. width
end

function M.encoding(value)
  return (value ~= "" and value or vim.o.encoding):upper()
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

return M
