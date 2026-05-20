local state = require("config.lualine_pane.state")
local util = require("config.lualine_pane.util")

local M = {}

local function command_output(cmd)
  if vim.system then
    local result = vim.system(cmd, { text = true }):wait()

    return table.concat({ result.stdout or "", result.stderr or "" }, "\n")
  end

  return vim.fn.system(cmd)
end

local node_runtime = {
  commands = {
    { "node", "--version" },
  },
  parse = function(output)
    return output:match("(v%d[%d%.%-]*)")
  end,
}

local runtime_specs = {
  lua = {
    commands = {
      { "lua", "-v" },
      { "luajit", "-v" },
    },
    parse = function(output)
      return output:match("LuaJIT%s+([%w%.%-]+)") or output:match("Lua%s+([%w%.%-]+)")
    end,
  },
  python = {
    commands = {
      { "python3", "--version" },
      { "python", "--version" },
    },
    parse = function(output)
      return output:match("Python%s+([%w%.%-]+)")
    end,
  },
  javascript = node_runtime,
  javascriptreact = node_runtime,
  typescript = node_runtime,
  typescriptreact = node_runtime,
  vue = node_runtime,
  svelte = node_runtime,
  go = {
    commands = {
      { "go", "version" },
    },
    parse = function(output)
      return output:match("go version%s+(go[%d%.]+)")
    end,
  },
  rust = {
    commands = {
      { "rustc", "--version" },
    },
    parse = function(output)
      return output:match("rustc%s+([%w%.%-]+)")
    end,
  },
  java = {
    commands = {
      { "java", "-version" },
    },
    parse = function(output)
      return output:match('version%s+"([^"]+)"') or output:match("openjdk%s+([%w%.%-]+)")
    end,
  },
  ruby = {
    commands = {
      { "ruby", "--version" },
    },
    parse = function(output)
      return output:match("ruby%s+([%w%.%-]+)")
    end,
  },
  php = {
    commands = {
      { "php", "--version" },
    },
    parse = function(output)
      return output:match("PHP%s+([%w%.%-]+)")
    end,
  },
  dart = {
    commands = {
      { "dart", "--version" },
    },
    parse = function(output)
      return output:match("Dart SDK version:%s+([%w%.%-]+)")
    end,
  },
  elixir = {
    commands = {
      { "elixir", "--version" },
    },
    parse = function(output)
      return output:match("Elixir%s+([%w%.%-]+)")
    end,
  },
  swift = {
    commands = {
      { "swift", "--version" },
    },
    parse = function(output)
      return output:match("Swift version%s+([%w%.%-]+)")
    end,
  },
  kotlin = {
    commands = {
      { "kotlinc", "-version" },
    },
    parse = function(output)
      return output:match("kotlinc[%w%-]*%s+([%w%.%-]+)")
    end,
  },
}

function M.version(ft)
  local spec = runtime_specs[ft]

  if not spec then
    return ""
  end

  local cached = state.runtime_cache[ft]

  if cached and state.now() - cached.checked_at < state.runtime_cache_ttl then
    return cached.version
  end

  local version = ""

  for _, cmd in ipairs(spec.commands) do
    if vim.fn.executable(cmd[1]) == 1 then
      version = util.trim(spec.parse(command_output(cmd)) or "")

      if version ~= "" then
        break
      end
    end
  end

  state.runtime_cache[ft] = {
    version = version,
    checked_at = state.now(),
  }

  return version
end

function M.os_info()
  if state.os_cache then
    return state.os_cache
  end

  local function cache(value)
    state.os_cache = value
    return value
  end

  local uname = state.uv.os_uname()
  local sysname = uname.sysname

  if sysname == "Darwin" then
    return cache(" macOS")
  end

  if sysname:match("Windows") or sysname == "Windows_NT" then
    return cache(" Windows")
  end

  if sysname == "Linux" then
    local ok, lines = pcall(vim.fn.readfile, "/etc/os-release")
    local values = {}

    if ok then
      for _, line in ipairs(lines) do
        local key, value = line:match("^([%w_]+)=(.*)$")

        if key and value then
          values[key] = util.trim(value:gsub('^"', ""):gsub('"$', ""))
        end
      end
    end

    local id = (values.ID or ""):lower()
    local id_like = (values.ID_LIKE or ""):lower()

    if id == "arch" or id_like:match("arch") then
      return cache("󰣇 Arch")
    end

    if id == "ubuntu" or id_like:match("ubuntu") then
      return cache(" Ubuntu")
    end

    if id == "fedora" or id_like:match("fedora") then
      return cache(" Fedora")
    end

    return cache(" Linux")
  end

  return cache(" " .. sysname)
end

return M
