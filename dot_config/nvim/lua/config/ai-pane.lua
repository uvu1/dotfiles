local M = {}

local RIGHT_WIDTH = 40

local function close_codecompanion_windows()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == "codecompanion" then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end
end

local function resize_right()
  vim.schedule(function()
    pcall(vim.cmd, "vertical resize " .. RIGHT_WIDTH)
    vim.wo.winfixwidth = true
  end)
end

local function set_winbar(active)
  local copilot = active == "copilot"
      and "%#TabLineSel#   Copilot Chat  "
      or "%#TabLine#   Copilot Chat  "

  local codex = active == "codex"
      and "%#TabLineSel#   Codex  "
      or "%#TabLine#   Codex  "

  vim.wo.winbar = copilot .. codex .. "%#TabLineFill#"
end

function M.copilot()
  close_codecompanion_windows()

  vim.cmd("botright vertical CodeCompanionChat adapter=copilot")

  resize_right()
  vim.schedule(function()
    set_winbar("copilot")
  end)
end

function M.codex()
  close_codecompanion_windows()

  vim.cmd("botright vertical CodeCompanionChat adapter=codex")

  resize_right()
  vim.schedule(function()
    set_winbar("codex")
  end)
end

function M.toggle()
  if vim.g.ai_pane_active == "copilot" then
    vim.g.ai_pane_active = "codex"
    M.codex()
  else
    vim.g.ai_pane_active = "copilot"
    M.copilot()
  end
end

function M.close()
  close_codecompanion_windows()
end

return M
