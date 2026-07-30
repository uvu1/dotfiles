-- VSCode の Test Explorer 相当。実行そのものは各言語のテストランナーに任せ、
-- neotest は検出・実行・結果表示だけを持つ。
--
-- ランナーの解決方針（アダプタごとに事情が違う）:
--   go / cargo  … アダプタ側にコマンドの差し替え口が無く、バイナリ名が固定
--                  （neotest-golang lib/cmd.lua、neotest-rust init.lua）。ただし
--                  go は go.mod の toolchain 行 + GOTOOLCHAIN=auto、cargo は
--                  rustup の proxy が rust-toolchain.toml を見るので、
--                  どちらも自分でプロジェクトの版に切り替わる。ラップ不要。
--   jest / vitest … 既定で node_modules/.bin を上に辿って探す。mise で包むより
--                  正確なので触らない（包むと DAP の runtimeExecutable が
--                  mise になって pwa-node が mise をデバッグしに行く）。
--   python      … pytest が入っているのは venv なので lib/python で解決する。
--                  nvim-dap の debugpy アダプタと同じ関数を共有する。
--                  venv が無い場合の mise 経由フォールバックだけは、neotest 側に
--                  env の指定口が無いため hook-env の PATH 問題（lib/mise の
--                  base_path）を踏む。venv があれば絶対パスなので影響しない。
--
-- cargo nextest（neotest-rust）は nix/home.nix の debugTools が供給する。
-- go / cargo / node は同じく nix の runtimes がフォールバックを供給し、
-- プロジェクトが版を pin していれば mise がそちらを PATH 前方に置く。
return {
  {
    "nvim-neotest/neotest",

    dependencies = {
      "nvim-neotest/nvim-nio",
      -- neotest 本体は plenary を使わないが、neotest-golang（plenary.scandir）と
      -- neotest-rust（plenary.job / path / context_manager）が要求する。
      "nvim-lua/plenary.nvim",
      "fredrikaverpil/neotest-golang",
      "nvim-neotest/neotest-python",
      "marilari88/neotest-vitest",
      "nvim-neotest/neotest-jest",
      "rouge8/neotest-rust",
    },

    keys = {
      {
        "<leader>Tt",
        function()
          require("neotest").run.run()
        end,
        desc = "Run nearest",
      },
      {
        "<leader>Tf",
        function()
          require("neotest").run.run(vim.fn.expand("%"))
        end,
        desc = "Run file",
      },
      {
        "<leader>Ta",
        function()
          require("neotest").run.run({ suite = true })
        end,
        desc = "Run suite",
      },
      {
        "<leader>Tl",
        function()
          require("neotest").run.run_last()
        end,
        desc = "Run last",
      },
      {
        "<leader>Td",
        function()
          require("neotest").run.run({ strategy = "dap" })
        end,
        desc = "Debug nearest",
      },
      {
        "<leader>TS",
        function()
          require("neotest").run.stop()
        end,
        desc = "Stop",
      },
      {
        "<leader>Ts",
        function()
          require("neotest").summary.toggle()
        end,
        desc = "Toggle summary",
      },
      {
        "<leader>To",
        function()
          require("neotest").output.open({ enter = true })
        end,
        desc = "Show output",
      },
      {
        "<leader>TO",
        function()
          require("neotest").output_panel.toggle()
        end,
        desc = "Toggle output panel",
      },
      {
        "<leader>Tw",
        function()
          require("neotest").watch.toggle()
        end,
        desc = "Toggle watch",
      },
    },

    opts = function()
      local python = require("lib.python")

      return {
        adapters = {
          -- neotest-golang は __call の中で options.setup を呼び、その戻りを
          -- filter_dir が読む。呼ばずに渡すと options が nil になるので、
          -- 既定のままでも必ず呼ぶ。
          require("neotest-golang")({}),

          require("neotest-python")({
            -- string[] を argv としてそのまま前置してくれるので、venv でも
            -- mise 経由でも同じ 1 行で通る。DAP strategy のときは同じ値が
            -- デバッグ設定の python にも渡る。
            python = function(root)
              return python.argv(root)
            end,
          }),

          -- jest / vitest は node_modules/.bin から自分で解決する。
          require("neotest-vitest"),
          require("neotest-jest"),

          -- dap_adapter の既定は "codelldb" で、plugins/dap.lua が登録する
          -- アダプタ名と一致している。
          require("neotest-rust"),
        },

        -- 失敗は diagnostic consumer が行内に出すので、quickfix まで奪わせない。
        -- quickfix は :grep と picker の <a-q> が使う場所。
        quickfix = { enabled = false },

        -- 行内表示は tiny-inline-diagnostic が持っているので、
        -- neotest 側は sign だけにして二重に出さない。
        status = { virtual_text = false, signs = true },

        -- floating.border は書かない。既定の nil が nvim_open_win に渡って
        -- winborder が効く（options.lua の winborder 集約と同じ規則）。
      }
    end,
  },
}
