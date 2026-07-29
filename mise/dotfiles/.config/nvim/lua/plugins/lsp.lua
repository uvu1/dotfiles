return {
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
      "b0o/schemastore.nvim",
    },
    config = function()
      local mise = require("lib.mise")

      local ai_filetypes = {
        codecompanion = true,
        ["pane-tabs-ai"] = true,
      }

      local yaml_schemas = require("schemastore").yaml.schemas()
      yaml_schemas.kubernetes = {
        "k8s/**/*.yaml",
        "k8s/**/*.yml",
        "kubernetes/**/*.yaml",
        "kubernetes/**/*.yml",
        "manifests/**/*.yaml",
        "manifests/**/*.yml",
        "clusters/**/*.yaml",
        "clusters/**/*.yml",
        "applications/**/*.yaml",
        "applications/**/*.yml",
        "applicationsets/**/*.yaml",
        "applicationsets/**/*.yml",
      }

      -- redhat.telemetry と yaml.format.enable は lspconfig の既定が入れてくれる。
      -- schemaStore を切って schemastore.nvim 側のスキーマだけを使う。
      -- ここは必ず settings 配下に置く。vim.lsp.config は未知のトップレベル
      -- キーを無検査で受理するため、外に書くと黙って無視される。
      vim.lsp.config("yamlls", {
        settings = {
          yaml = {
            keyOrdering = false,
            schemaStore = {
              enable = false,
              url = "",
            },
            schemas = yaml_schemas,
          },
        },
      })

      vim.lsp.config("jsonls", {
        settings = {
          json = {
            validate = { enable = true },
            schemas = require("schemastore").json.schemas(),
          },
        },
      })

      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = {
              version = "LuaJIT",
            },
            diagnostics = {
              globals = { "vim" },
            },
            -- nvim_get_runtime_file("", true) はこの config() 実行時点の rtp を
            -- スナップショットするため、遅延ロードされるプラグインが入らず
            -- 内容がロード順に左右される。固定のパスを渡す。
            -- プラグイン自体の型が必要になったら lazydev.nvim を入れる。
            workspace = {
              library = {
                vim.env.VIMRUNTIME .. "/lua",
                vim.fn.stdpath("config") .. "/lua",
                "${3rd}/luv/library",
              },
              checkThirdParty = false,
            },
            telemetry = {
              enable = false,
            },
          },
        },
      })

      -- tailwindcss の lspconfig 既定は filetypes が約 50 種あり、root_files の
      -- 末尾が .git なので、CSS の無い git リポジトリでも markdown 等に attach
      -- してしまう。使う filetype に絞り、tailwind の実設定を必須にする。
      vim.lsp.config("tailwindcss", {
        filetypes = {
          "css",
          "less",
          "postcss",
          "sass",
          "scss",
          "html",
          "javascript",
          "javascriptreact",
          "typescript",
          "typescriptreact",
          "svelte",
          "vue",
        },
        root_dir = function(bufnr, on_dir)
          local project = require("lib.project")
          local configs = {
            "tailwind.config.js",
            "tailwind.config.cjs",
            "tailwind.config.mjs",
            "tailwind.config.ts",
            "postcss.config.js",
            "postcss.config.cjs",
            "postcss.config.mjs",
            "postcss.config.ts",
          }

          -- tailwind v4 は設定ファイルを必須としないので package.json の宣言も見る。
          if
            not project.root_has(bufnr, configs)
            and not project.root_file_contains(bufnr, { "package.json", "package.json5" }, "tailwindcss")
          then
            return
          end

          on_dir(vim.fs.root(bufnr, vim.list_extend({ "package.json" }, configs)))
        end,
      })

      -- tailwind の @apply/@tailwind を未知の at-rule として報告するため切る。
      -- css は biome / tailwindcss 側でも診断が出るので二重三重になっていた。
      vim.lsp.config("cssls", {
        settings = {
          css = { validate = false },
          scss = { validate = false },
          less = { validate = false },
        },
      })

      -- ここから 4 本だけ mise x でラップする。基準は「サーバがプロジェクトの
      -- 処理系を実行・内省しないと正しい答えを出せないか」。バージョン依存の実体が
      -- リポジトリ内のファイル（node_modules/typescript、compile_commands.json、
      -- JSON schema、.eslintrc）なら、サーバ自身が workspace から解決するので
      -- ラップは無益なうえ、プロジェクトが古い node を pin していると逆に壊れる。

      -- rust-analyzer は `rustc --print sysroot` と `cargo metadata` を実行する。
      -- mise の rust バージョン切り替えは PATH ではなく RUSTUP_TOOLCHAIN 経由
      -- （installs/rust/<v> はすべて ~/.cargo/bin への symlink）なので、
      -- mise x を通さないとプロジェクトの toolchain が反映されない。
      -- 注意: lspconfig の root_dir は nvim の環境で cargo metadata を呼ぶため、
      -- root 検出だけはグローバルの rustup cargo を使う（ラップの外側）。
      vim.lsp.config("rust_analyzer", {
        cmd = mise.lsp_cmd({ "rust-analyzer" }),
        settings = {
          ["rust-analyzer"] = {
            cargo = {
              allFeatures = true,
            },
            check = {
              command = "clippy",
            },
          },
        },
      })

      -- gopls は go list を実行する。stdlib・build tag・module graph がすべて
      -- ツールチェイン由来。
      vim.lsp.config("gopls", {
        cmd = mise.lsp_cmd({ "gopls" }),
      })

      -- ruby のバージョンと bundler がそのまま解析対象。lspconfig 既定の cmd も
      -- 同じ理由で cwd = root_dir を渡している。Gemfile.lock に ruby-lsp があれば
      -- bundle exec 経由にする（gem のバイナリはビルド時の ruby に紐づくため）。
      vim.lsp.config("ruby_lsp", {
        cmd = mise.lsp_cmd({ "ruby-lsp" }, { bundled = "ruby-lsp" }),
      })

      -- インタプリタそのものが stdlib と site-packages。
      -- basedpyright は npm 製で shebang が node なので、MISE_DISABLE_TOOLS で
      -- node を外すと mise が継承分の node も含めて PATH から落とし、
      -- `env: 'node': No such file or directory` で起動できない（実測）。
      -- プロジェクトの node で動かす。
      vim.lsp.config("basedpyright", {
        cmd = mise.lsp_cmd({ "basedpyright-langserver", "--stdio" }),
      })

      -- eslint は lspconfig の root_dir が設定ファイルの実在を要求するので、
      -- biome / tailwind のような追加ゲートは不要。整形は conform に任せて切る。
      vim.lsp.config("eslint", {
        settings = {
          format = false,
          run = "onSave",
        },
      })

      -- copilot LSP: インライン補完は Neovim 0.12 の vim.lsp.inline_completion で直接消費する。
      -- lspconfig の既定は telemetryLevel = "all" なので明示的に切る。
      vim.lsp.config("copilot", {
        settings = {
          telemetry = {
            telemetryLevel = "off",
          },
        },
      })

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("ai-pane-completion", { clear = true }),
        pattern = { "codecompanion", "pane-tabs-ai" },
        callback = function(args)
          vim.b[args.buf].completion = false

          if vim.lsp.inline_completion then
            vim.lsp.inline_completion.enable(false, { bufnr = args.buf })
          end
        end,
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("copilot-inline", { clear = true }),
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if not client then
            return
          end

          if client.name == "copilot" then
            vim.lsp.inline_completion.enable(not ai_filetypes[vim.bo[args.buf].filetype], { bufnr = args.buf })
          end
        end,
      })

      -- 有効サーバ集合の唯一の正本。実体は mise/config.unix.toml が供給する
      -- （mason は廃止した）。ここに無いサーバは起動しない。
      vim.lsp.enable({
        "basedpyright",
        "biome",
        "clangd",
        "copilot",
        "cssls",
        "eslint",
        "gopls",
        "html",
        "jsonls",
        "lua_ls",
        "ruby_lsp",
        "rust_analyzer",
        "tailwindcss",
        "ts_ls",
        "yamlls",
      })
    end,
  },
}
