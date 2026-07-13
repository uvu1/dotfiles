local state = require("config.lualine_pane.state")
local util = require("config.lualine_pane.util")

local M = {}

function M.current_time()
  return "󰥔 " .. os.date("%H:%M")
end

function M.setup()
  if state.clock_timer then
    return
  end

  state.clock_timer = state.uv.new_timer()
  state.clock_timer:start(30000, 30000, vim.schedule_wrap(util.refresh_statusline))

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("LualinePaneClock", { clear = true }),
    once = true,
    callback = function()
      if not state.clock_timer then
        return
      end

      state.clock_timer:stop()
      state.clock_timer:close()
      state.clock_timer = nil
    end,
  })
end

return M
