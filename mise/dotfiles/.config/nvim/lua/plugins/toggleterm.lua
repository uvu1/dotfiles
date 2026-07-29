-- フロート端末をエディタペインに重なる位置・サイズで開くための座標計算。
-- 旧実装は pane-tabs.buffers.kind に依存していたが、pane-tabs を廃止したので
-- win_gettype == "" の通常ウィンドウ検出だけで editor_win を決める。
local function normal_win(win)
  return win and vim.api.nvim_win_is_valid(win) and vim.fn.win_gettype(win) == ""
end

local function editor_win()
  local current = vim.api.nvim_get_current_win()

  if normal_win(current) then
    return current
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if normal_win(win) then
      return win
    end
  end

  return current
end

local function term_height()
  local win = editor_win()
  local height = normal_win(win) and vim.api.nvim_win_get_height(win) or vim.o.lines
  local preferred = math.floor(height * 0.34)

  return math.max(1, math.min(16, math.max(10, preferred), height - 2))
end

local function term_width()
  local win = editor_win()
  local width = normal_win(win) and vim.api.nvim_win_get_width(win) or vim.o.columns

  return math.max(1, width - 2)
end

local function term_row()
  local win = editor_win()

  if not normal_win(win) then
    return math.max(0, vim.o.lines - term_height() - 2)
  end

  local position = vim.api.nvim_win_get_position(win)
  local height = vim.api.nvim_win_get_height(win)

  return math.max(0, position[1] + height - term_height() - 2)
end

local function term_col()
  local win = editor_win()

  if not normal_win(win) then
    return 0
  end

  return vim.api.nvim_win_get_position(win)[2]
end

return {
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    cmd = {
      "ToggleTerm",
      "ToggleTermToggleAll",
      "TermExec",
      "TermNew",
      "TermSelect",
    },
    keys = {
      { "<leader>tt", "<cmd>ToggleTerm<cr>", mode = { "n", "t" }, desc = "Toggle terminal" },
    },
    opts = {
      direction = "float",
      hide_numbers = true,
      shade_terminals = false,
      start_in_insert = true,
      persist_size = false,
      float_opts = {
        relative = "editor",
        -- toggleterm だけは winborder に従わない（ui.lua が opts.border or "single"
        -- とハードコードしている）ので明示が要る。丸角にしたければ "curved"。
        border = "single",
        width = term_width,
        height = term_height,
        row = term_row,
        col = term_col,
        winblend = 0,
        zindex = 50,
        title_pos = "left",
      },
    },
  },
}
