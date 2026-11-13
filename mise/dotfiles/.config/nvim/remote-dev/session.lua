-- Read-only liveness probe; never trust a stale PID or a reused port.
local record = vim.env.NVIM_REMOTE_RECORD
local ok, value = pcall(function()
  return vim.json.decode(table.concat(vim.fn.readfile(record), "\n"))
end)
local prefix = vim.env.HOME .. "/.remote-nvim/run/"
if not ok or type(value) ~= "table" or not vim.startswith(tostring(value.address), prefix) then
  return
end
local connected, channel = pcall(vim.fn.sockconnect, "pipe", value.address, { rpc = true })
if not connected or channel == 0 then
  return
end
local alive, id = pcall(vim.rpcrequest, channel, "nvim_get_var", "remote_dev_session_id")
vim.fn.chanclose(channel)
if alive and id == record then
  io.write(vim.json.encode(value) .. "\n")
end
