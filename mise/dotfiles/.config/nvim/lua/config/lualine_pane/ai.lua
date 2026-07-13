local pane = require("config.lualine_pane.pane")
local state = require("config.lualine_pane.state")
local util = require("config.lualine_pane.util")

local M = {}

local MODEL_CATEGORIES = { "model" }
local THINKING_CATEGORIES = {
  "thought_level",
  "thinking_level",
  "reasoning_effort",
  "reasoning_level",
  "reasoning",
}

local function format_elapsed(ms)
  local seconds = math.max(0, math.floor(ms / 1000))

  if seconds < 60 then
    return seconds .. "s"
  end

  local minutes = math.floor(seconds / 60)
  local rest = seconds % 60

  if minutes < 60 then
    return ("%dm%02ds"):format(minutes, rest)
  end

  return ("%dh%02dm"):format(math.floor(minutes / 60), minutes % 60)
end

local function any_request_running()
  for _, request in pairs(state.ai_requests) do
    if request.running then
      return true
    end
  end

  return false
end

local function ensure_timer()
  if state.ai_timer then
    return
  end

  state.ai_timer = state.uv.new_timer()
  state.ai_timer:start(
    1000,
    1000,
    vim.schedule_wrap(function()
      util.refresh_statusline()

      if any_request_running() then
        return
      end

      state.ai_timer:stop()
      state.ai_timer:close()
      state.ai_timer = nil
    end)
  )
end

local function is_codecompanion_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].filetype == "codecompanion"
end

local function metadata(buf)
  return _G.codecompanion_chat_metadata and _G.codecompanion_chat_metadata[buf] or nil
end

local function chat_for_buf(buf)
  if not is_codecompanion_buf(buf) then
    return nil
  end

  local ok_codecompanion, codecompanion = pcall(require, "codecompanion")

  if ok_codecompanion and type(codecompanion.buf_get_chat) == "function" then
    local ok_chat, chat = pcall(codecompanion.buf_get_chat, buf)

    if ok_chat and chat then
      return chat
    end
  end

  local ok, chat = pcall(require, "codecompanion.interactions.chat")

  if not ok or type(chat.buf_get_chat) ~= "function" then
    return nil
  end

  local ok_chat, result = pcall(chat.buf_get_chat, buf)

  return ok_chat and result or nil
end

local function current_chat()
  local buf = pane.target_buf()

  return chat_for_buf(buf), buf
end

local function buffer_provider_name(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) and vim.b[buf].pane_tabs_ai_provider then
    return vim.b[buf].pane_tabs_ai_provider
  end

  return nil
end

local function provider_name(buf)
  local name = buffer_provider_name(buf)

  if name then
    return name
  end

  local ok, ai = pcall(require, "pane-tabs.pane.ai")

  if ok and type(ai.get_provider_name) == "function" then
    return ai.get_provider_name()
  end

  return nil
end

local function normalize_key(value)
  return tostring(value or ""):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
end

local function contains(list, value)
  value = normalize_key(value)

  for _, item in ipairs(list) do
    if value == normalize_key(item) then
      return true
    end
  end

  return false
end

local resolve_value

local function option_matches(opt, categories)
  return contains(categories, opt.category) or contains(categories, opt.id) or contains(categories, opt.name)
end

local function flatten_options(options, result)
  result = result or {}

  for _, item in ipairs(options or {}) do
    if item.group and item.options then
      flatten_options(item.options, result)
    else
      table.insert(result, item)
    end
  end

  return result
end

local function option_entry(opt)
  local entry = {
    current = opt.currentValue or opt.current or opt.value,
    name = opt.selected_name or opt.currentValue or opt.current or opt.value,
    option = opt,
  }

  for _, item in ipairs(flatten_options(opt.options or {})) do
    if item.value == entry.current then
      entry.name = item.name or item.value
      entry.item = item
      break
    end
  end

  return entry
end

local function metadata_option(buf, categories)
  local data = metadata(buf)
  local config_options = data and data.config_options

  if type(config_options) ~= "table" then
    return nil
  end

  for category, opt in pairs(config_options) do
    local entry = vim.tbl_extend("force", {
      category = category,
      id = category,
      name = category,
      selected_name = opt.name,
    }, opt)

    if option_matches(entry, categories) then
      return option_entry(entry)
    end
  end

  return nil
end

local function default_config_option(chat, categories)
  local options = chat and chat.adapter and chat.adapter.defaults and chat.adapter.defaults.session_config_options

  if type(options) ~= "table" then
    return nil
  end

  for category, value in pairs(options) do
    local opt = {
      category = category,
      id = category,
      name = category,
      currentValue = resolve_value(value, chat.adapter),
    }

    if option_matches(opt, categories) then
      return option_entry(opt)
    end
  end

  return nil
end

local function acp_call(chat, method)
  local connection = chat and chat.acp_connection

  if not connection or type(connection[method]) ~= "function" then
    return nil
  end

  local ok, result = pcall(connection[method], connection)

  return ok and result or nil
end

local function config_option(chat, categories)
  for _, opt in ipairs(acp_call(chat, "get_config_options") or {}) do
    if option_matches(opt, categories) then
      return option_entry(opt)
    end
  end

  return nil
end

function resolve_value(value, self)
  if type(value) ~= "function" then
    return value
  end

  local ok, resolved = pcall(value, self)

  return ok and resolved or nil
end

local function adapter_name(chat, buf)
  if chat and chat.adapter and chat.adapter.name then
    return chat.adapter.name
  end

  local data = metadata(buf)

  if data and data.adapter and data.adapter.name then
    return data.adapter.name
  end

  return nil
end

local function is_codex(chat, buf)
  local provider = buffer_provider_name(buf) or (not chat and provider_name(buf) or nil)
  local adapter = adapter_name(chat, buf)

  return normalize_key(provider) == "codex" or normalize_key(adapter):find("codex", 1, true) ~= nil
end

local function model_name(chat, buf)
  local data = metadata(buf)

  if chat and chat.adapter then
    if chat.adapter.type == "acp" then
      local acp_models = acp_call(chat, "get_models")

      if acp_models and acp_models.currentModelId and acp_models.currentModelId ~= "" then
        return acp_models.currentModelId
      end

      local model = config_option(chat, MODEL_CATEGORIES)

      if model and model.current and model.current ~= "" then
        return model.current
      end

      if data and data.adapter and data.adapter.model and data.adapter.model ~= "default" then
        return data.adapter.model
      end

      return chat.adapter.defaults and chat.adapter.defaults.model or nil
    end

    if chat.settings and chat.settings.model then
      return chat.settings.model
    end

    return chat.adapter.schema
        and chat.adapter.schema.model
        and resolve_value(chat.adapter.schema.model.default, chat.adapter)
      or nil
  end

  return data and data.adapter and data.adapter.model or nil
end

local function context_window_from_value(value)
  if type(value) ~= "table" then
    return nil
  end

  local candidates = {
    value.context_window,
    value.contextWindow,
    value.max_context_window,
    value.maxContextWindow,
    value.max_context_window_tokens,
    value.maxContextWindowTokens,
    value.model_context_window,
    value.modelContextWindow,
    value.model_context_window_tokens,
    value.modelContextWindowTokens,
    value.meta and value.meta.context_window,
    value.meta and value.meta.contextWindow,
    value.meta and value.meta.max_context_window,
    value.meta and value.meta.max_context_window_tokens,
    value.limits and value.limits.context_window,
    value.limits and value.limits.max_context_window,
    value.limits and value.limits.max_context_window_tokens,
    value.capabilities and value.capabilities.limits and value.capabilities.limits.context_window,
    value.capabilities and value.capabilities.limits and value.capabilities.limits.max_context_window,
    value.capabilities and value.capabilities.limits and value.capabilities.limits.max_context_window_tokens,
    value.opts and value.opts.context_window,
    value.opts and value.opts.max_context_window,
    value.opts and value.opts.max_context_window_tokens,
  }

  for _, candidate in ipairs(candidates) do
    local number = tonumber(candidate)

    if number and number > 0 then
      return number
    end
  end

  return nil
end

local function context_window_from_choices(chat, model)
  if not chat or not chat.adapter or not chat.adapter.schema or not chat.adapter.schema.model then
    return nil
  end

  local choices = resolve_value(chat.adapter.schema.model.choices, chat.adapter)

  if type(choices) ~= "table" then
    return nil
  end

  return context_window_from_value(choices[model])
end

local function codex_model_catalog()
  if state.ai_codex_model_catalog then
    return state.ai_codex_model_catalog
  end

  state.ai_codex_model_catalog = {}

  local path = vim.fn.expand("~/.codex/models_cache.json")

  if vim.fn.filereadable(path) ~= 1 then
    return state.ai_codex_model_catalog
  end

  local ok, decoded = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(path), "\n"))
  end)

  if not ok or type(decoded) ~= "table" then
    return state.ai_codex_model_catalog
  end

  for _, model in ipairs(decoded.models or {}) do
    if model.slug then
      state.ai_codex_model_catalog[model.slug] = model
    end
  end

  return state.ai_codex_model_catalog
end

local function codex_context_window(model)
  local info = model and codex_model_catalog()[model] or nil

  if not info then
    return nil
  end

  local window = tonumber(info.context_window or info.max_context_window)
  local percent = tonumber(info.effective_context_window_percent)

  if window and percent and percent > 0 and percent <= 100 then
    return math.floor(window * percent / 100)
  end

  return window
end

local function context_window(chat, buf, model)
  local data = metadata(buf)
  local model_option = config_option(chat, MODEL_CATEGORIES)

  return context_window_from_value(model_option and model_option.item)
    or context_window_from_value(chat and chat.adapter and chat.adapter.model and chat.adapter.model.info)
    or context_window_from_value(chat and chat.adapter and chat.adapter.meta)
    or context_window_from_value(data and data.adapter and data.adapter.model_info)
    or context_window_from_choices(chat, model)
    or (is_codex(chat, buf) and codex_context_window(model) or nil)
end

local function estimated_tokens(chat, buf)
  local data = metadata(buf)
  local reported = tonumber(chat and chat.ui and chat.ui.tokens) or tonumber(data and data.tokens) or 0

  if reported > 0 then
    return reported
  end

  if not chat then
    return nil
  end

  local messages = chat.messages or {}
  local last = messages[#messages]
  local cumulative = last and last._meta and tonumber(last._meta.cumulative_tokens)

  if cumulative and cumulative > 0 then
    return cumulative
  end

  local cache_key = table.concat({
    tostring(chat.id or ""),
    tostring(chat.cycle or ""),
    tostring(#messages),
    tostring(last and last._meta and last._meta.id or ""),
    tostring(last and last._meta and last._meta.cumulative_tokens or ""),
  }, ":")
  local cache = state.ai_context_cache[buf]

  if cache and cache.key == cache_key then
    return cache.tokens
  end

  local count = 0
  local ok, tokens = pcall(require, "codecompanion.utils.tokens")

  if ok then
    local ok_count, result = pcall(tokens.get_tokens, messages)
    count = ok_count and result or 0
  end

  state.ai_context_cache[buf] = {
    key = cache_key,
    tokens = count,
  }

  return count
end

local function context_usage_data()
  local chat, buf = current_chat()
  local model = model_name(chat, buf)
  local tokens = estimated_tokens(chat, buf)
  local window = context_window(chat, buf, model)

  if not tokens then
    return nil
  end

  return tokens, window, window and window > 0 and (tokens / window) or nil
end

local function request_buf(args)
  local data = args.data or {}
  local chat = data.chat or data.Chat
  local bufnr = data.bufnr
    or data.buf
    or data.chat_bufnr
    or data.chat_buffer
    or (type(chat) == "table" and (chat.bufnr or chat.buf))
    or args.buf

  if data.interaction and data.interaction ~= "chat" then
    return nil
  end

  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    local target = pane.target_buf()

    if is_codecompanion_buf(target) then
      return target
    end

    return nil
  end

  if args.match and args.match:match("^CodeCompanionChat") then
    return bufnr
  end

  if data.interaction == "chat" or is_codecompanion_buf(bufnr) then
    return bufnr
  end

  return nil
end

local function start_request(buf)
  if state.ai_requests[buf] and state.ai_requests[buf].running then
    return
  end

  state.ai_requests[buf] = {
    started_at = state.now(),
    finished_at = nil,
    running = true,
  }

  ensure_timer()
  util.refresh_statusline()
end

local function finish_request(buf)
  local request = state.ai_requests[buf]

  if not request then
    return
  end

  request.finished_at = state.now()
  request.running = false
  util.refresh_statusline()
end

function M.setup()
  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("LualinePaneAIRequests", { clear = true }),
    pattern = {
      "CodeCompanionChatSubmitted",
      "CodeCompanionChatDone",
      "CodeCompanionChatStopped",
      "CodeCompanionChatClosed",
      "CodeCompanionRequestStarted",
      "CodeCompanionRequestStreaming",
      "CodeCompanionRequestFinished",
    },
    callback = function(args)
      local buf = request_buf(args)

      if not buf then
        return
      end

      if
        args.match == "CodeCompanionChatSubmitted"
        or args.match == "CodeCompanionRequestStarted"
        or args.match == "CodeCompanionRequestStreaming"
      then
        start_request(buf)
        return
      end

      if args.match == "CodeCompanionChatClosed" then
        state.ai_requests[buf] = nil
        util.refresh_statusline()
        return
      end

      finish_request(buf)
    end,
  })

  vim.api.nvim_create_autocmd("User", {
    group = vim.api.nvim_create_augroup("LualinePaneAIStatus", { clear = true }),
    pattern = {
      "CodeCompanionACPConnected",
      "CodeCompanionChatACPConfigChanged",
      "CodeCompanionChatAdapter",
      "CodeCompanionChatCleared",
      "CodeCompanionChatCreated",
      "CodeCompanionChatModel",
      "CodeCompanionChatRestored",
    },
    callback = util.refresh_statusline,
  })
end

function M.elapsed()
  local request = state.ai_requests[pane.target_buf()]

  if not request or not request.running then
    return "󰚩 idle"
  end

  local elapsed_to = state.now()

  return "󰚩 working / " .. format_elapsed(elapsed_to - request.started_at)
end

function M.elapsed_color()
  local request = state.ai_requests[pane.target_buf()]

  if request and request.running then
    return { fg = state.colors.text, bg = state.colors.active, gui = "bold" }
  end

  return { fg = state.colors.inactive_text, bg = state.colors.inactive }
end

function M.has_model()
  return M.model() ~= ""
end

function M.model()
  local chat, buf = current_chat()
  local model = model_name(chat, buf)

  if type(model) ~= "string" or model == "" or model == "default" then
    return ""
  end

  return "󱚥 " .. model
end

function M.is_codex()
  local chat, buf = current_chat()

  return is_codex(chat, buf)
end

function M.has_thinking_level()
  return M.thinking_level() ~= ""
end

function M.thinking_level()
  local chat, buf = current_chat()

  if not is_codex(chat, buf) then
    return ""
  end

  local thinking = config_option(chat, THINKING_CATEGORIES)
    or metadata_option(buf, THINKING_CATEGORIES)
    or default_config_option(chat, THINKING_CATEGORIES)
  local value = thinking and (thinking.name or thinking.current)

  if type(value) ~= "string" or value == "" then
    return ""
  end

  return "󰧑 " .. value
end

function M.has_context_usage()
  return M.context_usage() ~= ""
end

function M.context_usage()
  local chat, buf = current_chat()

  if not is_codex(chat, buf) then
    return ""
  end

  local _, _, ratio = context_usage_data()

  if not ratio then
    return ""
  end

  return ("󰔢 %d%%%%"):format(math.floor(ratio * 100 + 0.5))
end

function M.context_usage_color()
  local _, _, ratio = context_usage_data()

  if ratio and ratio >= 0.9 then
    return { fg = state.colors.text, bg = "#F28FAD", gui = "bold" }
  end

  if ratio and ratio >= 0.7 then
    return { fg = state.colors.text, bg = "#F8BD96", gui = "bold" }
  end

  return { fg = state.colors.inactive_text, bg = state.colors.inactive }
end

return M
