local M = {}

M.uv = vim.uv or vim.loop

M.colors = {
  text = "#353042",
  active = "#FFA7C4",
  title = "#ea7599",
  inactive = "#857282",
  inactive_text = "#fff5fb",
  transparent = "none",
}

M.clock_timer = nil
M.os_cache = nil
M.runtime_cache = {}
M.runtime_cache_ttl = 5 * 60 * 1000

function M.now()
  return M.uv.now()
end

return M
