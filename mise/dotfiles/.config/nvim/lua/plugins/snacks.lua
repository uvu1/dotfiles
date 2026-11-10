-- ]r / [r は符号違いだけなので生成側で吸収する。v:count1 を掛けて 3]r も効かせる。
local function jump_reference(direction)
  return function()
    require("snacks").words.jump(direction * vim.v.count1, true)
  end
end

local function in_remote_mount()
  -- 未接続時は SSHFS プラグインを読み込まず、ローカル検索を維持する。
  local connections = package.loaded["remote-sshfs.connections"]
  if not connections or not connections.is_connected() then
    return false
  end

  local mount = connections.get_current_mount_point()
  if not mount or mount == "" then
    return false
  end

  mount = vim.fs.normalize(mount):gsub("/+$", "")
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  return cwd == mount or vim.startswith(cwd, mount .. "/")
end

local function workspace_picker(remote_method, local_method)
  return function()
    if in_remote_mount() then
      require("remote-sshfs.api")[remote_method]()
    else
      require("snacks").picker[local_method]()
    end
  end
end

return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
    opts = {
      bigfile = { enabled = true },
      quickfile = { enabled = true },

      dashboard = {
        enabled = true,
        width = 60,
        pane_gap = 4,

        preset = {
          header = [[
███╗   ██╗██╗   ██╗██╗███╗   ███╗
████╗  ██║██║   ██║██║████╗ ████║
██╔██╗ ██║██║   ██║██║██╔████╔██║
██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║
██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║
╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝
          ]],

          keys = {
            { icon = " ", key = "f", desc = "Find File", action = "<leader>ff" },
            { icon = " ", key = "g", desc = "Grep", action = "<leader>fg" },
            { icon = " ", key = "e", desc = "Explorer", action = "<leader>e" },
            { icon = " ", key = "r", desc = "Recent Files", action = "<leader>fr" },
            { icon = " ", key = "c", desc = "Config", action = "<leader>fc" },
            { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },

        sections = {
          { section = "header" },
          { section = "keys", gap = 1, padding = 1 },
          {
            icon = " ",
            title = "Recent Files",
            section = "recent_files",
            indent = 2,
            padding = { 1, 1 },
          },
          {
            icon = " ",
            title = "Projects",
            section = "projects",
            indent = 2,
            padding = { 1, 1 },
          },
          { section = "startup" },
        },
      },

      explorer = {
        enabled = true,
        replace_netrw = true,
        trash = true,
      },

      picker = {
        enabled = true,
        ui_select = true,

        -- WezTerm が CTRL+q を自身の leader に、herdr が prefix にしているため
        -- （wezterm/keybinds.lua、herdr/config.toml）、
        -- picker 既定の <c-q> = qflist は nvim に永久に届かない。届く別名を足す。
        -- 既定の <a-h>/<a-i>/<a-p> 等と同じ Alt 系なので到達性は揃う。
        win = {
          input = {
            keys = {
              ["<a-q>"] = { "qflist", mode = { "i", "n" } },
            },
          },
          list = {
            keys = {
              ["<a-q>"] = "qflist",
            },
          },
        },

        sources = {
          explorer = {
            hidden = true,
            ignored = true,
            follow_file = true,
            git_status = true,
            diagnostics = true,
            auto_close = false,

            layout = {
              preset = "sidebar",
              preview = false,
              hidden = { "input" },
              layout = {
                width = 0.18,
              },
            },
          },

          files = {
            hidden = true,
            ignored = false,
          },

          grep = {
            hidden = true,
            ignored = false,
          },
        },
      },

      indent = { enabled = true },
      scope = { enabled = true },
      statuscolumn = { enabled = true },

      input = { enabled = true },
      notifier = { enabled = true },

      -- VSCode のオカレンスハイライト。needs_setup = true なので既定は無効。
      -- 実体は documentHighlight 対応クライアントに限った document_highlight()。
      -- kawaii-theme は LspReference* と Visual が同じ背景色で、常時点くと
      -- 単語選択（v）と区別できない。必要なときだけ <leader>uo で入れる
      -- （オンの間だけ ]r / [r の参照移動も効く）。
      words = { enabled = false },

      -- lazygit.nvim の置き換え。setup 不要のオンデマンドモジュールだが、
      -- snacks が担当することを明示するために宣言しておく。
      lazygit = {},
    },

    keys = {
      {
        "<leader>e",
        function()
          require("lib.explorer").focus_or_open()
        end,
        desc = "Focus or open explorer",
      },

      {
        "<leader>dl",
        function()
          require("lib.git-log").line_history()
        end,
        mode = { "n", "x" },
        desc = "Commit log for line/selection",
      },

      {
        "<leader>gd",
        function()
          require("snacks").picker.lsp_definitions()
        end,
        desc = "Go to definitions",
      },
      {
        "<leader>gr",
        function()
          require("snacks").picker.lsp_references()
        end,
        desc = "Go to references",
      },
      {
        "<leader>gi",
        function()
          require("snacks").picker.lsp_implementations()
        end,
        desc = "Go to implementations",
      },
      {
        "<leader>gy",
        function()
          require("snacks").picker.lsp_type_definitions()
        end,
        desc = "Go to type definitions",
      },
      {
        "<leader>grn",
        function()
          vim.lsp.buf.rename()
        end,
        desc = "Rename symbol",
      },
      {
        "<leader>gci",
        function()
          require("snacks").picker.lsp_incoming_calls()
        end,
        desc = "Incoming calls",
      },
      {
        "<leader>gco",
        function()
          require("snacks").picker.lsp_outgoing_calls()
        end,
        desc = "Outgoing calls",
      },

      -- ]] / [[ は lib/symbol-nav が使っているので参照移動は ]r / [r に置く。
      { "]r", jump_reference(1), desc = "Next reference" },
      { "[r", jump_reference(-1), desc = "Prev reference" },

      {
        "<leader>ss",
        function()
          require("snacks").picker.lsp_symbols()
        end,
        desc = "File symbols",
      },
      {
        "<leader>sS",
        function()
          require("snacks").picker.lsp_workspace_symbols()
        end,
        desc = "Workspace symbols",
      },

      {
        "<leader>sf",
        function()
          require("snacks").picker.lsp_symbols({
            title = "Functions",
            filter = {
              default = { "Function", "Method", "Constructor" },
            },
          })
        end,
        desc = "File functions",
      },

      {
        "<leader>fe",
        function()
          require("snacks").explorer.open()
        end,
        desc = "Toggle explorer",
      },
      {
        "<leader>E",
        function()
          require("snacks").explorer.reveal()
        end,
        desc = "Reveal current file in explorer",
      },
      {
        "<leader>ff",
        workspace_picker("find_files", "files"),
        desc = "Find files",
      },
      {
        "<leader>fg",
        workspace_picker("live_grep", "grep"),
        desc = "Grep",
      },
      {
        "<leader>fb",
        function()
          require("snacks").picker.buffers()
        end,
        desc = "Buffers",
      },
      {
        "<leader>fr",
        function()
          require("snacks").picker.recent()
        end,
        desc = "Recent files",
      },
      {
        "<leader>fd",
        function()
          require("snacks").picker.diagnostics()
        end,
        desc = "Diagnostics",
      },
      {
        "<leader>fD",
        function()
          require("snacks").picker.diagnostics_buffer()
        end,
        desc = "Buffer diagnostics",
      },
      {
        "<leader>fc",
        function()
          require("snacks").picker.files({ cwd = vim.fn.stdpath("config") })
        end,
        desc = "Find config files",
      },

      -- lazygit.nvim の置き換え。カラースキーム連携と nvim-remote による編集連携は
      -- snacks 側が自動設定する。
      {
        "<leader>tl",
        function()
          require("snacks").lazygit.open()
        end,
        mode = { "n", "t" },
        desc = "Toggle lazygit",
      },
    },
  },
}
