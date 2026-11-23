local mise = require("lib.mise")
local M = {}
local cache, in_flight = {}, {}
local generation = 0
local ttl = 5 * 60 * 1000
local os_cache

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
    commands = { { "python", "--version" } },
    argv = function(dir)
      return vim.list_extend(require("lib.python").argv(dir), { "--version" })
    end,
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

-- ネストした mise 設定や言語プロジェクトも別の実行環境として扱う。
local markers = {
  "mise.toml",
  ".mise.toml",
  "mise.local.toml",
  ".mise.local.toml",
  ".tool-versions",
  ".node-version",
  ".python-version",
  ".ruby-version",
  "rust-toolchain.toml",
  "rust-toolchain",
  "package.json",
  "pyproject.toml",
  "setup.cfg",
  "mypy.ini",
  "pytest.ini",
  "setup.py",
  "Gemfile",
  "go.mod",
  "Cargo.toml",
  ".git",
}

function M.clear()
  cache, in_flight = {}, {}
  generation = generation + 1
end

local function refresh()
  local ok, lualine = pcall(require, "lualine")
  if ok then
    -- 更新イベントの管理は lualine のみ。非同期結果はそのキューへ渡す。
    lualine.refresh({ place = { "statusline" }, scope = "tabpage" })
  end
end

function M.version(ft, bufnr)
  local spec = runtime_specs[ft]
  if not spec then
    return ""
  end
  -- root の平坦な marker リストは優先順探索になる。グループ化して最も近い設定を選ぶ。
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  local dir = name ~= "" and (vim.fs.root(name, { markers }) or vim.fs.dirname(name)) or vim.uv.cwd()
  dir = mise.dir(dir)
  if not dir then
    return ""
  end
  local key = dir .. "\0" .. ft .. "\0" .. (ft == "python" and vim.env.VIRTUAL_ENV or "")
  local cached = cache[key]
  if cached and vim.uv.now() - cached.checked_at < ttl then
    return cached.version
  end
  if in_flight[key] then
    return cached and cached.version or ""
  end

  in_flight[key] = true
  local started_generation = generation
  local function finish(version)
    if generation ~= started_generation then
      return
    end
    cache[key] = { version = version, checked_at = vim.uv.now() }
    in_flight[key] = nil
    refresh()
  end
  local function detect(index)
    local command = spec.commands[index]
    if not command then
      finish("")
      return
    end
    -- project 内だけに入っているコマンドもあるため、継承 PATH の executable で除外しない。
    local ok = pcall(
      vim.system,
      spec.argv and spec.argv(dir) or mise.argv(command, dir),
      {
        cwd = dir,
        text = true,
        env = mise.spawn_env(),
        timeout = 3000,
      },
      vim.schedule_wrap(function(result)
        if generation ~= started_generation then
          return
        end
        local output = (result.stdout or "") .. "\n" .. (result.stderr or "")
        local version = result.code == 0 and spec.parse(output) or nil
        if version then
          finish(vim.trim(version))
        else
          detect(index + 1)
        end
      end)
    )
    if not ok then
      detect(index + 1)
    end
  end
  detect(1)
  return cached and cached.version or ""
end

function M.setup()
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("StatuslineRuntime", { clear = true }),
    pattern = vim.list_extend(vim.deepcopy(markers), { "mise.*.toml", ".mise.*.toml" }),
    callback = M.clear,
  })
end

function M.os_info()
  if os_cache then
    return os_cache
  end

  local function cache(value)
    os_cache = value
    return value
  end

  local uname = vim.uv.os_uname()
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
          values[key] = vim.trim(value:gsub('^"', ""):gsub('"$', ""))
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
