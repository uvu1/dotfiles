local M = {}

function M.target_win()
  local current = vim.api.nvim_get_current_win()

  if current and vim.api.nvim_win_is_valid(current) then
    return current
  end

  local win = tonumber(vim.g.statusline_winid)

  if win and vim.api.nvim_win_is_valid(win) then
    return win
  end

  return current
end

function M.focused_win()
  local win = tonumber(vim.g.actual_curwin)

  if win and vim.api.nvim_win_is_valid(win) then
    return win
  end

  return vim.api.nvim_get_current_win()
end

function M.target_buf()
  local win = M.target_win()

  if win and vim.api.nvim_win_is_valid(win) then
    return vim.api.nvim_win_get_buf(win)
  end

  return vim.api.nvim_get_current_buf()
end

--- snacks explorer picker whose window is `win`, or nil.
function M.explorer_picker_for_win(win)
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

  return nil
end

--- pane 種別。pane-tabs には依存せず、snacks explorer と buftype だけで判定する。
--- editor: 通常バッファ / explorer: snacks explorer / other: 端末など
function M.kind()
  if M.explorer_picker_for_win(M.target_win()) then
    return "explorer"
  end

  if vim.bo[M.target_buf()].buftype == "" then
    return "editor"
  end

  return "other"
end

function M.cond(kind)
  return function()
    return M.kind() == kind
  end
end

function M.focused_cond(kind)
  return function()
    return M.kind() == kind and M.target_win() == M.focused_win()
  end
end

return M
