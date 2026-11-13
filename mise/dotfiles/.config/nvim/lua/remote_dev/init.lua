local M = {}
local profile = require("remote_dev.profile")
local config = vim.fn.stdpath("config")
local cache = vim.fn.stdpath("cache") .. "/remote-dev"
local busy, active = false, nil

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Remote development" })
end

local function show(title, lines)
  local name = "remote-dev://" .. title
  local buf = vim.fn.bufnr(name)
  if buf == -1 then
    buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, name)
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].modifiable = false
  vim.cmd("botright split")
  vim.api.nvim_win_set_buf(0, buf)
end

local function ssh_binary()
  local value = vim.env.NVIM_REMOTE_SSH_BIN
  local path = vim.fn.expand("~/.config/nvim-remote/ssh-path")
  if not value and vim.fn.filereadable(path) == 1 then
    value = vim.fn.readfile(path)[1]
  end
  if not value or vim.fn.executable(value) ~= 1 then
    error(
      "Home ManagerのUnix版OpenSSH設定を適用するか、NVIM_REMOTE_SSH_BINに実体の絶対パスを指定してください"
    )
  end
  return value
end

local function save(name, value)
  vim.fn.mkdir(cache, "p", "0700")
  local path = cache .. "/" .. name .. ".json"
  vim.fn.writefile({ vim.json.encode(value) }, path)
  vim.uv.fs_chmod(path, 384)
  return path
end

local function last()
  local ok, value = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(cache .. "/last.json"), "\n"))
  end)
  return ok and value or nil
end

local function worker(action, value, callback)
  local args = { "python3", config .. "/remote-dev/worker.py", action, "--cache", cache }
  if value then
    vim.list_extend(args, { "--request", save("request", value) })
  end
  notify(
    action == "prepare" and "SSH先を確認し、手元で配布物を準備しています" or "RemoteDev: " .. action
  )
  local env = { NVIM_REMOTE_LOCAL_NVIM = vim.v.progpath }
  if action ~= "plan" then
    env.NVIM_REMOTE_SSH_BIN = ssh_binary()
  end
  vim.system(args, { text = true, env = env }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        busy = false
        show("error", vim.split(result.stderr ~= "" and result.stderr or "worker failed", "\n"))
        return
      end
      local ok, decoded = pcall(vim.json.decode, result.stdout)
      if not ok then
        busy = false
        notify("workerの応答を読めません: " .. result.stdout, vim.log.levels.ERROR)
        return
      end
      local success, err = pcall(callback, decoded)
      if not success then
        busy = false
        notify(tostring(err), vim.log.levels.ERROR)
      end
    end)
  end)
end

local function transport(host, extra)
  assert(host:match("^[%w_][%w_.@:+%-]*$") and not host:match("^docker:"), "不正なSSHホスト名")
  local args = {
    ssh_binary(),
    "-o",
    "ControlMaster=auto",
    "-o",
    "ControlPath=/tmp/rnvim-%C",
    "-o",
    "ControlPersist=600",
    "-o",
    "ConnectTimeout=10",
    "-o",
    "ServerAliveInterval=15",
    "-o",
    "ServerAliveCountMax=3",
  }
  vim.list_extend(args, extra or {})
  args[#args + 1] = host
  return args
end

local function stop_tunnel(value)
  pcall(vim.fn.jobstop, value.job)
  -- A multiplexed -N client may exit while its forwarding stays in the
  -- master. Cancel the forwarding explicitly rather than relying on its PID.
  vim.system(transport(value.host, { "-O", "cancel", "-L", value.forward }), {}, function()
    local stat = vim.uv.fs_lstat(value.address)
    if stat and stat.type == "socket" then
      vim.uv.fs_unlink(value.address)
    end
  end)
end

local function authenticate(host, callback)
  local function done()
    local ok, err = pcall(callback)
    if not ok then
      busy = false
      notify(tostring(err), vim.log.levels.ERROR)
    end
  end
  local args = transport(host, { "-o", "BatchMode=yes", "-N", "-f" })
  vim.system(args, { text = true }, function(result)
    vim.schedule(function()
      if result.code == 0 then
        done()
        return
      end
      -- Host-key/password prompts are shown in a real terminal; no secrets are saved.
      local buf = vim.api.nvim_create_buf(false, true)
      vim.cmd("botright split")
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, buf)
      local job = vim.fn.jobstart(transport(host, { "-N", "-f" }), {
        term = true,
        on_exit = function(_, code)
          vim.schedule(function()
            if code == 0 then
              if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
              end
              done()
            else
              busy = false
              notify("SSH認証が完了しませんでした", vim.log.levels.ERROR)
            end
          end)
        end,
      })
      if job <= 0 then
        busy = false
        error("SSH認証端末を起動できません")
      end
      vim.cmd.startinsert()
    end)
  end)
end

local function connect_ui(value)
  assert(vim.startswith(value.address, value.home .. "/.remote-nvim/run/"), "不正なサーバーアドレス")
  local run = cache .. "/run"
  vim.fn.mkdir(run, "p", "0700")
  assert(vim.uv.fs_chmod(run, 448))
  local address = run .. "/s" .. vim.fn.getpid() .. "-" .. tostring(math.floor(vim.uv.hrtime() / 1e6))
  assert(
    #address <= 103 and #value.address <= 103,
    "Unix socketのパスが長すぎます（HOME/cacheのパスを短くしてください）"
  )
  assert(
    not (address .. value.address):find("[:%%\n\r]"),
    "Unix socketのパスに使用できない文字があります"
  )
  local forward = address .. ":" .. value.address
  local job
  job = vim.fn.jobstart(
    transport(value.host, {
      "-o",
      "BatchMode=yes",
      "-o",
      "ExitOnForwardFailure=yes",
      "-o",
      "StreamLocalBindMask=0177",
      "-o",
      "ServerAliveInterval=15",
      "-o",
      "ServerAliveCountMax=3",
      "-N",
      "-L",
      forward,
    }),
    {
      on_exit = function(_, code)
        if active and active.job == job and code ~= 0 then
          local tunnel = active
          vim.schedule(function()
            if active ~= tunnel then
              return
            end
            active = nil
            stop_tunnel(tunnel)
            notify(
              "SSHトンネルが切れました。RemoteDevReconnectで作業を再開できます",
              vim.log.levels.WARN
            )
          end)
        end
      end,
    }
  )
  assert(job > 0, "SSHトンネルを起動できません")
  local tunnel = { job = job, host = value.host, forward = forward, address = address }
  local channel = 0
  local timer = assert(vim.uv.new_timer())
  local attempts = 0
  timer:start(
    50,
    100,
    vim.schedule_wrap(function()
      attempts = attempts + 1
      local connected, result = pcall(vim.fn.sockconnect, "pipe", address, { rpc = true })
      channel = connected and result or 0
      if channel == 0 and attempts < 100 then
        return
      end
      timer:stop()
      timer:close()
      busy = false
      if channel == 0 then
        stop_tunnel(tunnel)
        notify("SSHトンネルの接続がタイムアウトしました", vim.log.levels.ERROR)
        return
      end
      local ok, err = pcall(function()
        assert(
          vim.rpcrequest(channel, "nvim_get_var", "remote_dev_session_id") == value.record,
          "接続先のセッションが一致しません"
        )
        assert(
          #vim.rpcrequest(channel, "nvim_list_uis") == 0,
          "このセッションには既にUIが接続しています"
        )
        local back = vim.v.servername ~= "" and vim.v.servername or vim.fn.serverstart()
        vim.rpcrequest(channel, "nvim_set_var", "remote_dev_return", back)
        active = tunnel
        save("last", value)
        vim.fn.chanclose(channel)
        vim.cmd.connect(address)
      end)
      if not ok then
        pcall(vim.fn.chanclose, channel)
        stop_tunnel(tunnel)
        active = nil
        notify(tostring(err), vim.log.levels.ERROR)
      end
    end)
  )
end

local function plugins()
  local lock = vim.json.decode(table.concat(vim.fn.readfile(config .. "/lazy-lock.json"), "\n"))
  local result = {}
  for name, plugin in pairs(require("lazy.core.config").plugins) do
    if not vim.tbl_contains(profile.disabled, name) then
      assert(lock[name], "lazy-lock.jsonに固定されていないプラグイン: " .. name)
      result[name] = { url = plugin.url, commit = lock[name].commit }
    end
  end
  return result
end

local function begin(host, project)
  authenticate(host, function()
    local plugin = require("lazy.core.config").plugins["remote.nvim"]
    assert(plugin and vim.fn.isdirectory(plugin.dir) == 1, "Lazyでremote.nvimを導入してください")
    worker("prepare", {
      host = host,
      project = project,
      config = config,
      version = "v" .. tostring(vim.version()):match("^[%d.]+"),
      plugin = plugin.dir,
      plugins = plugins(),
    }, function(value)
      show("deployment", {
        "# 配置内容",
        "",
        "接続先: " .. value.host,
        "作業場所: " .. value.project,
        "環境: " .. value.platform,
        "配置先: " .. value.release,
        "",
        "Neovim・固定したプラグイン・LSP・整形・検索ツールを配置します。",
        "既存releaseとセッションは保持します。",
      })
      vim.ui.select(
        { "配置して接続", "キャンセル" },
        { prompt = "上記の内容でSSH先へ適用" },
        function(choice)
          if choice ~= "配置して接続" then
            busy = false
            return
          end
          authenticate(value.host, function()
            worker("deploy", value, function(deployed)
              worker("attach", deployed, connect_ui)
            end)
          end)
        end
      )
    end)
  end)
end

function M.connect(host)
  if profile.enabled then
    return notify("別ホストへの接続は手元のNeovimから実行してください", vim.log.levels.WARN)
  end
  if busy then
    return notify("接続処理を実行中です")
  end
  busy = true
  local function choose(value)
    if not value or value == "" then
      busy = false
      return
    end
    vim.ui.input({ prompt = "SSH先の作業ディレクトリ: ", default = "~/" }, function(project)
      if not project or project == "" then
        busy = false
        return
      end
      local ok, err = pcall(begin, value, project)
      if not ok then
        busy = false
        notify(tostring(err), vim.log.levels.ERROR)
      end
    end)
  end
  if host and host ~= "" then
    choose(host)
    return
  end
  require("lazy").load({ plugins = { "remote.nvim" } })
  local hosts = require("remote.ssh_config").hosts({ vim.fn.expand("~/.ssh/config") })
  local options = {}
  for _, item in ipairs(hosts) do
    options[#options + 1] = item.host
  end
  options[#options + 1] = "ホスト名を入力"
  vim.ui.select(options, { prompt = "SSH接続先" }, function(value)
    if value == "ホスト名を入力" then
      vim.ui.input({ prompt = "SSH host: " }, choose)
    else
      choose(value)
    end
  end)
end

function M.reconnect()
  if profile.enabled then
    return notify("手元へ戻ってRemoteDevReconnectを実行してください")
  end
  local value = last()
  if not value then
    return notify("前回の接続がありません")
  end
  if busy then
    return notify("接続処理を実行中です")
  end
  busy = true
  authenticate(value.host, function()
    worker("attach", value, connect_ui)
  end)
end

function M.disconnect()
  if profile.enabled then
    local address = vim.g.remote_dev_return
    if not address then
      return notify("手元のUI接続がありません")
    end
    -- The TUI resolves this address on the client machine, not this server.
    vim.cmd.connect(address)
  elseif active then
    stop_tunnel(active)
    active = nil
  end
end

function M.health()
  local lines = { "# Remote development", "", "profile: " .. (profile.enabled and "remote" or "local") }
  if profile.enabled then
    lines[#lines + 1] = "release: " .. (vim.env.NVIM_REMOTE_RELEASE or "unknown")
    for _, command in ipairs({
      "rg",
      "fd",
      "basedpyright-langserver",
      "typescript-language-server",
      "lua-language-server",
      "clangd",
      "gopls",
      "goimports",
      "gofumpt",
      "rust-analyzer",
      "biome",
      "prettier",
      "ruff",
      "stylua",
      "ruby",
      "bundle",
      "ruby-lsp",
      "go",
      "cargo",
      "rustfmt",
      "cc",
      "tree-sitter",
      "git",
    }) do
      local path = vim.fn.exepath(command)
      lines[#lines + 1] = ("- %s: %s"):format(
        command,
        path ~= "" and path or "未導入（プロジェクト依存はbundle等で用意）"
      )
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "LSP: :checkhealth vim.lsp / :LspLog、整形: :ConformInfo"
  else
    local ok, value = pcall(ssh_binary)
    lines[#lines + 1] = "ssh: " .. (ok and value or "未設定: " .. value)
    for _, command in ipairs({ "python3", "npm", "go", "git", "curl", "tar" }) do
      lines[#lines + 1] = command .. ": " .. vim.fn.exepath(command)
    end
    lines[#lines + 1] = "SSH認証はUnix版OpenSSHと~/.ssh/configを使用します。"
  end
  show("health", lines)
end

function M.plan()
  if profile.enabled then
    return notify("配置予定は手元のNeovimからRemoteDevPlanで確認してください")
  end
  worker("plan", nil, function(value)
    local lines = {
      "# Remote development: 配置予定",
      "",
      "SSH接続・ダウンロード・配置は行っていません。",
      "",
      "Neovim: " .. value.artifacts.nvim_version,
      "配置先: ~/.remote-nvim/releases/<構成のハッシュ>",
      "",
      "## OS/CPU別の公式成果物",
    }
    for _, target in ipairs(vim.fn.sort(vim.tbl_keys(value.artifacts.platforms))) do
      lines[#lines + 1] = ""
      lines[#lines + 1] = "### " .. target
      for _, name in ipairs(vim.fn.sort(vim.tbl_keys(value.artifacts.platforms[target]))) do
        local artifact = value.artifacts.platforms[target][name]
        lines[#lines + 1] = "- " .. name .. ": " .. artifact.url
        lines[#lines + 1] = "  SHA256: " .. artifact.sha256
      end
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "## 専用Nodeで動くツール"
    for name, version in pairs(value.npm) do
      lines[#lines + 1] = "- " .. name .. " " .. version
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] =
      "Goツールはgo.mod/go.sumに固定したソースから手元でクロスビルドします。"
    lines[#lines + 1] =
      "Ruby LSP・言語ランタイム・プロジェクトの依存関係はSSH先で用意します。"
    show("plan", lines)
  end)
end

function M.setup()
  for name, callback in pairs({
    Connect = function(opts)
      M.connect(opts.args)
    end,
    Disconnect = M.disconnect,
    Reconnect = M.reconnect,
    Plan = M.plan,
    Health = M.health,
  }) do
    vim.api.nvim_create_user_command("RemoteDev" .. name, function(opts)
      local ok, err = pcall(callback, opts)
      if not ok then
        busy = false
        notify(tostring(err), vim.log.levels.ERROR)
      end
    end, { nargs = name == "Connect" and "?" or 0, force = true })
  end
  for key, name in pairs({ c = "Connect", d = "Disconnect", r = "Reconnect", h = "Health", p = "Plan" }) do
    vim.keymap.set("n", "<leader>m" .. key, "<cmd>RemoteDev" .. name .. "<cr>", { desc = "Remote " .. name })
  end
  vim.api.nvim_create_autocmd("UIEnter", {
    group = vim.api.nvim_create_augroup("remote-dev-return", { clear = true }),
    callback = function()
      if active then
        local tunnel = active
        active = nil
        stop_tunnel(tunnel)
      end
    end,
  })
end

return M
