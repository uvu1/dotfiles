local pane = require("config.lualine_pane.pane")
local state = require("config.lualine_pane.state")

local M = {}

function M.dirname(path)
  if vim.fs and vim.fs.dirname then
    return vim.fs.dirname(path)
  end

  return vim.fn.fnamemodify(path, ":h")
end

function M.find_git_root(path)
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

  return git and M.dirname(git) or nil
end

function M.normalize_path(path)
  if not path or path == "" then
    return ""
  end

  if vim.fs and vim.fs.normalize then
    return vim.fs.normalize(path)
  end

  return path
end

function M.path_is_inside(path, root)
  path = M.normalize_path(path)
  root = M.normalize_path(root)

  if path == "" or root == "" then
    return false
  end

  if path == root then
    return true
  end

  if root:sub(-1) ~= "/" then
    root = root .. "/"
  end

  return path:sub(1, #root) == root
end

function M.root()
  local buf = pane.target_buf()
  local name = vim.api.nvim_buf_get_name(buf)
  local cwd = state.uv.cwd()
  local base = name ~= "" and M.dirname(name) or cwd
  local git_root = M.find_git_root(base)

  if git_root then
    return git_root
  end

  if cwd and cwd ~= "" and (name == "" or M.path_is_inside(name, cwd)) then
    return cwd
  end

  return base or cwd or ""
end

function M.buffer_in_project(buf, root)
  local name = vim.api.nvim_buf_get_name(buf)

  if name == "" then
    return buf == pane.target_buf()
  end

  return M.path_is_inside(name, root)
end

return M
