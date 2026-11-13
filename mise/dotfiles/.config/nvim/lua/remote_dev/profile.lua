local M = {}

M.enabled = vim.env.NVIM_REMOTE_DEV == "1"
M.disabled = {
  "remote.nvim",
  "remote-sshfs.nvim",
  "claudecode.nvim",
  "nvim-dap",
  "nvim-dap-go",
  "nvim-dap-view",
  "neotest",
  "neotest-golang",
  "neotest-jest",
  "neotest-python",
  "neotest-rust",
  "neotest-vitest",
}

function M.spec()
  local spec = { { import = "plugins" } }
  if M.enabled then
    for _, name in ipairs(M.disabled) do
      spec[#spec + 1] = { name, enabled = false }
    end
  end
  return spec
end

return M
