local M = {}

-- 標準 :connect ssh:// は NVIM_APPNAME=nvim-remote で起動する。
-- 通常の ssh + nvim にも同じ端末・依存コマンドの扱いを適用する。
M.remote = vim.env.NVIM_APPNAME == "nvim-remote"
  or (vim.env.SSH_CONNECTION or "") ~= ""
  or (vim.env.SSH_TTY or "") ~= ""

local tools = {}

-- SSH先でのみ使うmise定義から、shimではなく固定版の実体を取得する。
-- 起動時のインストール・trust・プロジェクト設定の変更は行わない。
function M.tool(name)
  if not M.remote or vim.fn.executable("mise") == 0 then
    return nil
  end
  if tools[name] == nil then
    local result = vim
      .system({ "mise", "-C", vim.fn.stdpath("config") .. "/tools", "which", name }, {
        text = true,
        env = { MISE_AUTO_INSTALL = "0", MISE_EXEC_AUTO_INSTALL = "0" },
      })
      :wait(5000)
    local path = vim.trim(result.stdout or "")
    tools[name] = result.code == 0 and vim.fn.executable(path) == 1 and path or false
  end
  return tools[name] or nil
end

function M.node_env()
  local node = M.tool("node")
  return node and { PATH = vim.fs.dirname(node) .. ":" .. vim.env.PATH } or nil
end

function M.spec()
  local spec = { { import = "plugins" } }
  if M.remote then
    -- リモート専用に配布していた構成と同じく、編集・LSP・整形を基本にする。
    for _, name in ipairs({
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
    }) do
      spec[#spec + 1] = { name, enabled = false }
    end
  end
  return spec
end

return M
