-- AtCoder / Competitive Programming（旧 config/keymap/competitive.lua をキー据え置きで移設）
local function opts(desc)
  return { noremap = true, silent = true, desc = desc }
end

local function save_current_buffer()
  if vim.bo.buftype ~= "" or vim.api.nvim_buf_get_name(0) == "" or not vim.bo.modifiable then
    return true
  end

  local ok, err = pcall(vim.cmd, "silent update")
  if not ok then
    vim.notify("AtCoder: failed to write current buffer: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  return true
end

local function current_file_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" then
    return nil
  end

  return vim.fn.fnamemodify(name, ":p:h")
end

local function term(cmd, term_opts)
  term_opts = term_opts or {}
  local cwd = term_opts.cwd
  if type(cwd) == "function" then
    cwd = cwd()
  end

  if not save_current_buffer() then
    return
  end

  vim.cmd("botright 15new")
  vim.bo.buflisted = false

  local job_opts = { term = true }
  if cwd and cwd ~= "" then
    job_opts.cwd = cwd
  end

  local job_id = vim.fn.jobstart({ vim.o.shell, vim.o.shellcmdflag, cmd }, job_opts)
  if job_id <= 0 then
    vim.notify("AtCoder: failed to start terminal: " .. cmd, vim.log.levels.ERROR)
    vim.cmd("bdelete!")
    return
  end

  vim.cmd("startinsert")
end

local function input_term(prompt, cmd_builder)
  vim.ui.input({ prompt = prompt }, function(input)
    if not input or input == "" then
      return
    end

    term(cmd_builder(input))
  end)
end

vim.keymap.set("n", "<leader>ct", function()
  term("mise run test", { cwd = current_file_dir })
end, opts("AtCoder: sample test"))

vim.keymap.set("n", "<leader>cd", function()
  term("mise run test-debug")
end, opts("AtCoder: sample test debug"))

vim.keymap.set("n", "<leader>cr", function()
  term("mise run run")
end, opts("AtCoder: run with stdin"))

vim.keymap.set("n", "<leader>cu", function()
  term("mise run submit", { cwd = current_file_dir })
end, opts("AtCoder: submit"))

vim.keymap.set("n", "<leader>cb", function()
  term("mise run build-image")
end, opts("AtCoder: build Podman image"))

vim.keymap.set("n", "<leader>cn", function()
  input_term("contest id: ", function(contest)
    return "mise run new " .. vim.fn.shellescape(contest)
  end)
end, opts("AtCoder: new contest"))

vim.keymap.set("n", "<leader>co", function()
  term("mise exec --command 'oj login --check https://atcoder.jp/ && acc session'")
end, opts("AtCoder: check login"))
