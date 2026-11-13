local M = {}

function M.start()
  local record = assert(vim.env.NVIM_REMOTE_RECORD)
  local run = vim.env.HOME .. "/.remote-nvim/run"
  vim.fn.mkdir(run, "p", "0700")
  assert(vim.uv.fs_chmod(run, 448)) -- 0700
  vim.g.remote_dev_session_id = record
  local value = {
    address = vim.fn.serverstart(run .. "/s" .. vim.fn.getpid()),
    release = vim.env.NVIM_REMOTE_RELEASE,
    version = ("v%d.%d.%d"):format(vim.version().major, vim.version().minor, vim.version().patch),
    pid = vim.fn.getpid(),
  }
  local temp = record .. "." .. value.pid
  vim.fn.writefile({ vim.json.encode(value) }, temp)
  assert(vim.uv.fs_chmod(temp, 384)) -- 0600
  assert(vim.uv.fs_rename(temp, record))
end

return M
