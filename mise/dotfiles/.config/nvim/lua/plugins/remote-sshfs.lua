-- SSHFS は手元の Nix profile、接続先は既存の SSH/SFTP を使う。
-- WSL の ssh は Home Manager が置く Windows OpenSSH ラッパが正本。
return {
  "nosduco/remote-sshfs.nvim",
  cmd = {
    "RemoteSSHFSConnect",
    "RemoteSSHFSDisconnect",
    "RemoteSSHFSFindFiles",
    "RemoteSSHFSLiveGrep",
  },
  dependencies = { "folke/snacks.nvim", "nvim-lua/plenary.nvim" },
  opts = function()
    local connections = { sshfs_args = { "-o reconnect", "-o ConnectTimeout=5" } }

    if vim.fn.has("wsl") == 1 then
      table.insert(connections.sshfs_args, "-o ssh_command=" .. vim.fn.expand("~/.local/bin/ssh"))

      -- Windows OpenSSH が読む SSH config と known_hosts をホスト選択にも使う。
      -- USERPROFILE は端末固有なので、固定パスをリポジトリへ書かない。
      -- WSL の作業ディレクトリが UNC の場合、cmd.exe は案内文も stdout に出す。
      local lines = vim.fn.systemlist({ "cmd.exe", "/C", "echo", "%USERPROFILE%" })
      local profile = vim.fn.trim(lines[#lines] or "")
      if vim.v.shell_error == 0 and profile ~= "" then
        local home = vim.fn.trim(vim.fn.system({ "wslpath", "-u", profile }))
        if vim.v.shell_error == 0 and home ~= "" then
          connections.ssh_configs = { home .. "/.ssh/config" }
          connections.ssh_known_hosts = home .. "/.ssh/known_hosts"
        end
      end
    end

    return { connections = connections, ui = { picker = "snacks" } }
  end,
}
