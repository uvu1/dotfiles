-- Isolated worker: remote.nvim's hardcoded `ssh` resolves to Unix OpenSSH here.
local request = vim.json.decode(table.concat(vim.fn.readfile(arg[1]), "\n"))
vim.opt.rtp:prepend(request.plugin)
local tools = {}
for name, spec in pairs(request.tools) do
  local item = spec
  tools[name] = {
    version = item.sha256,
    bin = name,
    url = function()
      return item.url
    end,
  }
end
require("remote").setup({
  prefix = request.release,
  config_dir = request.config,
  nvim_version = request.version,
  tools = tools,
  copy_dirs = { data = { "lazy", "portable" } },
})
local ok, err = pcall(require("remote").provision, request.host, function(message)
  io.stderr:write(message .. "\n")
end)
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd.cquit()
end
