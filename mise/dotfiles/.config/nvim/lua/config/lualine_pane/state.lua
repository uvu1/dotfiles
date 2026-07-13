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

M.ai_requests = {}
M.ai_timer = nil
M.ai_context_cache = {}
M.ai_codex_model_catalog = nil
M.clock_timer = nil
M.os_cache = nil
M.runtime_cache = {}
M.runtime_cache_ttl = 5 * 60 * 1000
M.weather_cache_ttl = 10 * 60 * 1000
M.weather_retry_ttl = 60 * 1000
M.weather = {
  in_flight = false,
  last_fetch_at = 0,
  last_success_at = 0,
  text = "󰖐 --",
}

function M.now()
  return M.uv.now()
end

return M
