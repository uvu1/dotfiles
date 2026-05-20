local state = require("config.lualine_pane.state")
local util = require("config.lualine_pane.util")

local M = {}

local function weather_icon(code)
  if code == 0 then
    return "󰖙"
  end

  if code == 1 or code == 2 then
    return "󰖕"
  end

  if code == 3 then
    return "󰖐"
  end

  if code == 45 or code == 48 then
    return "󰖑"
  end

  if (code >= 51 and code <= 67) or (code >= 80 and code <= 82) then
    return "󰖗"
  end

  if (code >= 71 and code <= 77) or code == 85 or code == 86 then
    return "󰖘"
  end

  if code >= 95 and code <= 99 then
    return "󰖓"
  end

  return "󰖐"
end

local function parse_response(body)
  local ok, data = pcall(vim.json.decode, body)

  if not ok or type(data) ~= "table" or type(data.current) ~= "table" then
    return nil
  end

  local temp = tonumber(data.current.temperature_2m)
  local code = tonumber(data.current.weather_code)

  if not temp or not code then
    return nil
  end

  local unit = data.current_units and data.current_units.temperature_2m or "°C"

  return ("%s Nagoya %.0f%s"):format(weather_icon(code), temp, unit)
end

local function fetch()
  local weather = state.weather

  if weather.in_flight or not vim.system then
    return
  end

  local current = state.now()

  if weather.last_fetch_at > 0 and current - weather.last_fetch_at < state.weather_retry_ttl then
    return
  end

  if weather.last_success_at > 0 and current - weather.last_success_at < state.weather_cache_ttl then
    return
  end

  if vim.fn.executable("curl") ~= 1 then
    weather.text = "󰖐 Nagoya N/A"
    weather.last_fetch_at = current
    return
  end

  weather.in_flight = true
  weather.last_fetch_at = current

  local url = "https://api.open-meteo.com/v1/forecast?latitude=35.1815&longitude=136.9066&current=temperature_2m,weather_code&timezone=Asia%2FTokyo"

  vim.system({
    "curl",
    "-fsSL",
    "--connect-timeout",
    "3",
    "--max-time",
    "6",
    url,
  }, { text = true }, function(result)
    vim.schedule(function()
      weather.in_flight = false

      if result.code == 0 and result.stdout and result.stdout ~= "" then
        local text = parse_response(result.stdout)

        if text then
          weather.text = text
          weather.last_success_at = state.now()
        elseif weather.last_success_at == 0 then
          weather.text = "󰖐 Nagoya N/A"
        end
      elseif weather.last_success_at == 0 then
        weather.text = "󰖐 Nagoya N/A"
      end

      util.refresh_statusline()
    end)
  end)
end

function M.current()
  fetch()

  return state.weather.text
end

return M
