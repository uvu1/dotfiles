return {
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
      "b0o/schemastore.nvim",
    },
    config = function()
      local mise = require("lib.mise")

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

      -- typescript-language-server 5.3.0 は inlay hint を全部 'none'/false に
      -- 既定しているので、明示しないと vim.lsp.inlay_hint を有効にしても何も返らない。
      -- サーバは typescript.inlayHints と javascript.inlayHints の両方を読むため、
      -- 同じ table を両方から参照する。...MatchesName 系だけ false にして
      -- 「引数名と変数名が同じとき」の冗長なヒントを抑える。
      local ts_inlay_hints = {
        includeInlayEnumMemberValueHints = true,
        includeInlayFunctionLikeReturnTypeHints = true,
        includeInlayFunctionParameterTypeHints = true,
        includeInlayParameterNameHints = "all",
        includeInlayParameterNameHintsWhenArgumentMatchesName = false,
        includeInlayPropertyDeclarationTypeHints = true,
        includeInlayVariableTypeHints = true,
        includeInlayVariableTypeHintsWhenTypeMatchesName = false,
      }

      vim.lsp.config("ts_ls", {
        settings = {
          typescript = { inlayHints = ts_inlay_hints },
          javascript = { inlayHints = ts_inlay_hints },
        },
      })

      -- ここから 4 本だけ mise x でラップする。基準は「サーバがプロジェクトの
      -- 処理系を実行・内省しないと正しい答えを出せないか」。バージョン依存の実体が
      -- リポジトリ内のファイル（node_modules/typescript、compile_commands.json、
      -- JSON schema、.eslintrc）なら、サーバ自身が workspace から解決するので
      -- ラップは無益なうえ、プロジェクトが古い node を pin していると逆に壊れる。

      -- rust-analyzer は `rustc --print sysroot` と `cargo metadata` を実行する。
      -- サーバ本体と既定の toolchain は nix profile 由来だが、プロジェクトが mise で
      -- rust を宣言している場合の切り替えは PATH ではなく RUSTUP_TOOLCHAIN 経由
      -- （installs/rust/<v> はすべて ~/.cargo/bin への symlink）なので、
      -- mise x を通さないとプロジェクトの toolchain が反映されない。
      -- 注意: lspconfig の root_dir は nvim の環境で cargo metadata を呼ぶため、
      -- root 検出だけは nvim 起動時に解決された cargo を使う（ラップの外側）。
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
      -- hints は gopls 0.23.0 の全 8 種（api-json で確認）。すべて既定 false なので
      -- 明示しないと inlay hint は空のまま。うるさければ <leader>uh で切る。
      vim.lsp.config("gopls", {
        cmd = mise.lsp_cmd({ "gopls" }),
        settings = {
          gopls = {
            hints = {
              assignVariableTypes = true,
              compositeLiteralFields = true,
              compositeLiteralTypes = true,
              constantValues = true,
              functionTypeParameters = true,
              ignoredError = true,
              parameterNames = true,
              rangeVariableTypes = true,
            },
          },
        },
      })

      -- ruby のバージョンと bundler がそのまま解析対象。lspconfig 既定の cmd も
      -- 同じ理由で cwd = root_dir を渡している。Gemfile.lock に ruby-lsp があれば
      -- bundle exec 経由にする（gem のバイナリはビルド時の ruby に紐づくため）。
      vim.lsp.config("ruby_lsp", {
        cmd = mise.lsp_cmd({ "ruby-lsp" }, { bundled = "ruby-lsp" }),
      })

      -- インタプリタそのものが stdlib と site-packages なので、プロジェクトの
      -- python を掴ませる必要がある。サーバ自身の node は nixpkgs が shebang を
      -- 絶対パスに書き換えているため（buildNpmPackage の patchShebangs）、
      -- PATH 上の node には依存しない。空 env でも起動することを実測済み。
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

      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("ai-pane-completion", { clear = true }),
        pattern = { "codecompanion", "pane-tabs-ai" },
        callback = function(args)
          vim.b[args.buf].completion = false
        end,
      })

      -- 有効サーバ集合の唯一の正本。実体は nix/home.nix の devTools が供給する
      -- （mason は廃止し、mise からも移した）。ここに無いサーバは起動しない。
      vim.lsp.enable({
        "basedpyright",
        "biome",
        "clangd",
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

      -- Neovim 0.12 の組込み機能。LspAttach autocmd は要らない。
      -- filter 無しの enable() は vim.g のグローバルマーカーを立てるだけで、
      -- 実際の attach は client.lua が接続後に _capability.is_enabled() を見て行う
      -- （＝これ以降に起動するサーバにも自動で伝播する）。
      -- codelens も同様で、描画は nvim_set_decoration_provider なので
      -- CursorHold での手動 refresh は不要。
      vim.lsp.inlay_hint.enable(true)
      vim.lsp.codelens.enable(true)
      vim.lsp.linked_editing_range.enable(true)

      -- document_color は 0.12 では既定で ON。既定の 'background' は値そのものを
      -- 塗るので、VSCode のように左へスウォッチを出す 'virtual' に変えるだけ。
      -- cssls と tailwindcss が対応し、Tailwind のクラス名にも色が出る。
      vim.lsp.document_color.enable(true, nil, { style = "virtual" })
    end,
  },
}
