-- VSCode のデバッグ機能。アダプタの実体は nix/home.nix の debugTools が供給する
-- （delve / codelldb / js-debug）。グローバルに使うツールは nix、という
-- AGENTS.md の方針どおり mise には何も置いていない。
--
-- キーは <leader>D だけにする。F5 系は張らない（LSP 側の F キーを「vim の
-- 操作感を保つ」方針で撤去した判断と揃える）。

--- args を尋ねる設定値。nvim-dap は「関数が返したサスペンド中の coroutine」を
--- セッション開始時に resume する（dap.lua の eval_option）ので、この形にすると
--- snacks が差し替えた vim.ui.input をそのまま使える。
--- @return thread
local function prompt_args()
  return coroutine.create(function(dap_co)
    vim.ui.input({ prompt = "Args: " }, function(input)
      coroutine.resume(dap_co, require("dap.utils").splitstr(input or ""))
    end)
  end)
end

-- ブレークポイントの見た目。nvim-dap の既定は "B"/"C"/"R"/"L"/"→" のテキストを
-- SignColumn 色で出すので、状態の区別が付かない。sign_try_define は既に定義済みの
-- 名前を上書きしないため、ここで先に定義したものが残る。
local SIGNS = {
  DapBreakpoint = { text = "●", texthl = "DiagnosticError" },
  DapBreakpointCondition = { text = "◆", texthl = "DiagnosticWarn" },
  DapLogPoint = { text = "◇", texthl = "DiagnosticInfo" },
  DapBreakpointRejected = { text = "○", texthl = "DiagnosticHint" },
  DapStopped = { text = "▶", texthl = "DiagnosticOk", linehl = "debugPC" },
}

return {
  {
    "mfussenegger/nvim-dap",

    dependencies = {
      "igorlfs/nvim-dap-view",
      "leoluz/nvim-dap-go",
      -- overseer は setup 時に pcall(require, "dap") した結果へ
      -- preLaunchTask / postDebugTask と JSON5 デコーダのパッチを当てる
      -- （overseer/init.lua の enable_dap）。dap が未ロードだと黙って何も
      -- しないので、読み込み順を lazy に保証させる。
      "stevearc/overseer.nvim",
    },

    keys = {
      {
        "<leader>Dc",
        function()
          require("dap").continue()
        end,
        desc = "Continue / Start",
      },
      {
        "<leader>Db",
        function()
          require("dap").toggle_breakpoint()
        end,
        desc = "Toggle breakpoint",
      },
      {
        "<leader>DB",
        function()
          vim.ui.input({ prompt = "Breakpoint condition: " }, function(input)
            if input and input ~= "" then
              require("dap").set_breakpoint(input)
            end
          end)
        end,
        desc = "Conditional breakpoint",
      },
      {
        "<leader>DL",
        function()
          vim.ui.input({ prompt = "Log message: " }, function(input)
            if input and input ~= "" then
              require("dap").set_breakpoint(nil, nil, input)
            end
          end)
        end,
        desc = "Log point",
      },
      {
        "<leader>Dx",
        function()
          require("dap").clear_breakpoints()
        end,
        desc = "Clear breakpoints",
      },
      {
        "<leader>Do",
        function()
          require("dap").step_over()
        end,
        desc = "Step over",
      },
      {
        "<leader>Di",
        function()
          require("dap").step_into()
        end,
        desc = "Step into",
      },
      {
        "<leader>DO",
        function()
          require("dap").step_out()
        end,
        desc = "Step out",
      },
      {
        "<leader>Dg",
        function()
          require("dap").run_to_cursor()
        end,
        desc = "Run to cursor",
      },
      {
        "<leader>Dp",
        function()
          require("dap").pause()
        end,
        desc = "Pause",
      },
      {
        "<leader>Dr",
        function()
          require("dap").restart()
        end,
        desc = "Restart session",
      },
      {
        "<leader>Dl",
        function()
          require("dap").run_last()
        end,
        desc = "Run last",
      },
      {
        "<leader>Dt",
        function()
          require("dap").terminate()
        end,
        desc = "Terminate",
      },
      {
        "<leader>Dv",
        function()
          require("dap-view").toggle()
        end,
        desc = "Toggle debug view",
      },
      {
        "<leader>De",
        function()
          require("dap-view").hover()
        end,
        mode = { "n", "x" },
        desc = "Evaluate",
      },
      {
        "<leader>Dw",
        function()
          require("dap-view").add_expr()
        end,
        mode = { "n", "x" },
        desc = "Watch expression",
      },
    },

    config = function()
      local dap = require("dap")
      local python = require("lib.python")

      for name, opts in pairs(SIGNS) do
        vim.fn.sign_define(name, opts)
      end

      -- .vscode/launch.json は 0.12 の nvim-dap が providers 経由で on-demand に
      -- 読む（dap.lua の providers.configs["dap.launch.json"]）。
      -- load_launchjs は deprecated なので呼ばない。コメント付き launch.json は
      -- overseer が差し替える JSON5 デコーダが処理する。

      -- Go -----------------------------------------------------------------
      -- nvim-dap-go が delve の server アダプタ（dlv dap -l 127.0.0.1:${port}）と
      -- launch 設定 7 種を登録する。neotest-golang の既定 dap_mode も同じ
      -- プラグインへ委譲するので、Go のデバッグ経路はここ 1 箇所に集約される。
      --
      -- dlv は lib/mise でラップしない。ターゲットのビルドは dlv が go に委譲し、
      -- go 自身が go.mod の go / toolchain 行と GOTOOLCHAIN=auto でプロジェクトの
      -- ツールチェインへ切り替えるため、gopls に必要だったラップが不要になる。
      require("dap-go").setup()

      -- Python -------------------------------------------------------------
      -- debugpy はグローバルに置かない。他のアダプタと違って「単体の実行ファイル」
      -- ではなく python パッケージで、デバッグ対象と同じインタプリタから import
      -- できる必要がある。代わりにアダプタ自体をプロジェクトの python で起動する。
      -- debugpy はアダプタ側の実装をデバッグ対象へ注入する（VSCode が debugpy を
      -- 同梱して任意のインタプリタに使うのと同じ形）ので、デバッグ対象の python を
      -- 別途指定する必要はない。プロジェクト側に debugpy があることだけが前提。
      dap.adapters.python = function(callback, config)
        if config.request == "attach" then
          local connect = config.connect or config
          callback({
            type = "server",
            host = connect.host or "127.0.0.1",
            port = assert(connect.port, "attach には connect.port が必要"),
            options = { source_filetype = "python" },
          })
          return
        end

        local argv = python.argv(python.root(0))
        callback({
          type = "executable",
          command = argv[1],
          args = vim.list_extend(vim.list_slice(argv, 2), { "-m", "debugpy.adapter" }),
          options = {
            source_filetype = "python",
            -- venv が無く mise 経由に落ちたときのため。options.env は uv.spawn の
            -- env なので既存環境ごと渡す必要があり、hook-env モードでは PATH を
            -- activate 前に戻さないと mise が root のツールを再付与しない
            -- （lib/mise の spawn_env / base_path）。
            env = require("lib.mise").spawn_env(),
          },
        })
      end
      -- neotest-python は type = "python"、手書きの launch.json は "debugpy" を
      -- 使うことがあるので両方を同じ実装に向ける。
      dap.adapters.debugpy = dap.adapters.python

      -- debugpy はこの独自イベントを投げる。購読者が居ないと毎セッション
      -- 警告が出るので黙らせる。
      dap.listeners.before["event_debugpySockets"]["debugpy"] = function() end

      dap.configurations.python = {
        {
          type = "python",
          request = "launch",
          name = "Launch file",
          program = "${file}",
          console = "integratedTerminal",
          cwd = "${workspaceFolder}",
        },
        {
          type = "python",
          request = "launch",
          name = "Launch file (args)",
          program = "${file}",
          args = prompt_args,
          console = "integratedTerminal",
          cwd = "${workspaceFolder}",
        },
        {
          type = "python",
          request = "attach",
          name = "Attach (127.0.0.1:5678)",
          connect = { host = "127.0.0.1", port = 5678 },
        },
      }

      -- TS / JS ------------------------------------------------------------
      -- bin/js-debug は dapDebugServer.js を node で起動するラッパで、引数は
      -- <port> <host>（実測: 指定ポートで listen し DAP の initialize に success で
      -- 応答した）。pwa-* の全 type を 1 つのサーバが処理するので、アダプタは
      -- type 名だけ違う同じ定義になる。
      for _, name in ipairs({ "pwa-node", "pwa-chrome" }) do
        dap.adapters[name] = {
          type = "server",
          host = "127.0.0.1",
          port = "${port}",
          executable = {
            command = "js-debug",
            args = { "${port}", "127.0.0.1" },
          },
        }
      end

      -- Rust / C++ ---------------------------------------------------------
      -- codelldb は VSCode 拡張の中の実行ファイルなので nix/home.nix が bin へ
      -- 1 本だけ symlink している。--port で DAP サーバとして起動する
      -- （実測: symlink 経由でも liblldb を見失わず initialize に success で応答）。
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = {
          command = "codelldb",
          args = { "--port", "${port}" },
        },
      }

      -- 設定は「どの filetype に配るか」だけが違う。nvim-dap は
      -- dap.configurations を読むだけで書き換えないので、同じテーブルを
      -- 複数の filetype から共有してよい（launch.json は別 provider が返す）。
      local shared = {
        {
          -- Node は 22 以降 .ts を素で実行できるので、TS も loader なしで動く。
          { "javascript", "javascriptreact", "typescript", "typescriptreact" },
          {
            {
              type = "pwa-node",
              request = "launch",
              name = "Launch file",
              program = "${file}",
              cwd = "${workspaceFolder}",
              sourceMaps = true,
            },
            {
              type = "pwa-node",
              request = "launch",
              name = "Launch file (args)",
              program = "${file}",
              args = prompt_args,
              cwd = "${workspaceFolder}",
              sourceMaps = true,
            },
            {
              type = "pwa-node",
              request = "attach",
              name = "Attach to process",
              processId = "${command:pickProcess}",
              cwd = "${workspaceFolder}",
              sourceMaps = true,
            },
          },
        },
        {
          { "c", "cpp", "rust" },
          {
            {
              -- 既にビルド済みの実行ファイルを選ぶ。${command:pickFile} は
              -- nvim-dap 組込みのプレースホルダで、既定で実行可能ファイルだけを出す。
              type = "codelldb",
              request = "launch",
              name = "Launch executable",
              program = "${command:pickFile}",
              cwd = "${workspaceFolder}",
              stopOnEntry = false,
            },
            {
              type = "codelldb",
              request = "launch",
              name = "Launch executable (args)",
              program = "${command:pickFile}",
              args = prompt_args,
              cwd = "${workspaceFolder}",
              stopOnEntry = false,
            },
            {
              type = "codelldb",
              request = "attach",
              name = "Attach to process",
              pid = "${command:pickProcess}",
              cwd = "${workspaceFolder}",
            },
          },
        },
      }

      for _, entry in ipairs(shared) do
        local filetypes, configurations = entry[1], entry[2]
        for _, filetype in ipairs(filetypes) do
          dap.configurations[filetype] = configurations
        end
      end
    end,
  },

  {
    "igorlfs/nvim-dap-view",
    opts = {
      -- セッション開始で開き、終了で閉じる。VSCode のデバッグビューと同じ挙動。
      auto_toggle = true,
      -- nvim-dap-virtual-text を入れない理由がこれ。dap-view が同等の実装を
      -- 内蔵している（0.12 以上が必要で、この構成は 0.12.4）。
      virtual_text = { enabled = true },
      winbar = {
        -- VSCode のパネル順（Variables → Watch → Call Stack → Breakpoints）に揃える。
        sections = { "scopes", "watches", "threads", "breakpoints", "exceptions", "repl" },
        default_section = "scopes",
      },
      -- help / hover の border は書かない。既定の nil が nvim_open_win に
      -- 素通しされて winborder が効く（options.lua の winborder 集約と同じ規則）。
    },
  },
}
