local M = {}

--- Line range of the current visual selection, or the cursor line otherwise.
--- Leaves visual mode so the picker opens from a clean state.
--- @return integer from
--- @return integer to
local function selected_range()
  local mode = vim.fn.mode()
  if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
    local line = vim.fn.line(".")
    return line, line
  end

  local from, to = vim.fn.line("v"), vim.fn.line(".")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)

  if from > to then
    from, to = to, from
  end

  return from, to
end

--- Pick through the commits that touched the current line or visual selection
--- (`git log -L`). Confirming opens that single commit in Diffview.
function M.line_history()
  local buf = vim.api.nvim_get_current_buf()
  local file = vim.api.nvim_buf_get_name(buf)

  if file == "" or vim.bo[buf].buftype ~= "" then
    vim.notify("No file to show history for", vim.log.levels.WARN)
    return
  end

  local from, to = selected_range()

  return require("snacks").picker.git_log({
    cwd = vim.fs.dirname(file),
    cmd_args = { "-L", ("%d,%d:%s"):format(from, to, file) },
    title = ("Log %s:%d-%d"):format(vim.fn.fnamemodify(file, ":t"), from, to),
    transform = function(item)
      item.file = file
      return item
    end,
    confirm = function(picker, item)
      picker:close()
      if not item or not item.commit then
        return
      end

      -- git root relative, since Diffview resolves pathspecs from the repo root
      local pathspec = item.cwd and vim.fs.relpath(item.cwd, file) or file
      vim.cmd({ cmd = "DiffviewOpen", args = { item.commit .. "^!", "--", pathspec } })
    end,
  })
end

return M
