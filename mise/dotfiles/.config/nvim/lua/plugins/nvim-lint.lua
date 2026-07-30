return {
  {
    "mfussenegger/nvim-lint",
    -- biomejs / haml-lint は stdin=false でディスク上のファイルを lint する。
    -- auto-save は BufLeave/FocusLost のみ（config/autocmds.lua）なので
    -- InsertLeave 時点の診断は必ず古い。契機を保存後と読み込み後に限る。
    event = { "BufReadPost", "BufWritePost" },

    config = function()
      local lint = require("lint")
      local mise = require("lib.mise")
      local project = require("lib.project")

      -- haml には LSP も treesitter パーサも存在せず、nvim-lint にも定義が無いので
      -- 自前で書く。JSON reporter を使うのは linter_name が取れるため（既定の
      -- テキスト reporter は `path:line [W] [Correctable] Name: message` 形式）。
      -- location は line のみで column を持たないため行頭に付ける。
      lint.linters.haml_lint = {
        name = "haml_lint",
        cmd = "haml-lint",
        args = { "--reporter", "json" },
        stdin = false,
        append_fname = true,
        stream = "stdout",
        ignore_exitcode = true, -- 指摘があると非 0 で終わる
        parser = function(output)
          local diagnostics = {}

          local ok, decoded = pcall(vim.json.decode, output)
          if not ok or type(decoded) ~= "table" then
            return diagnostics
          end

          for _, file in ipairs(decoded.files or {}) do
            for _, offense in ipairs(file.offenses or {}) do
              local name = offense.linter_name
              table.insert(diagnostics, {
                lnum = math.max((offense.location or {}).line or 1, 1) - 1,
                col = 0,
                message = name and ("%s: %s"):format(name, offense.message) or offense.message,
                source = "haml-lint",
                code = name,
                severity = offense.severity == "error" and vim.diagnostic.severity.ERROR
                  or vim.diagnostic.severity.WARN,
              })
            end
          end

          return diagnostics
        end,
      }

      local web = { "biomejs" }

      lint.linters_by_ft = {
        typescript = web,
        typescriptreact = web,

        javascript = web,
        javascriptreact = web,

        json = web,
        jsonc = web,
        css = web,

        yaml = { "yamllint" },

        python = { "ruff" },

        go = { "golangcilint" },

        haml = { "haml_lint" },

        -- ruby に rubocop は入れない。ruby-lsp が bundle 内の rubocop で診断を
        -- 出すため、足すと二重診断になる（docs/nvim-lsp-audit.md Finding 4 と同型）。
      }

      -- linter → 走らせる条件。プロジェクトが採用していない流派の診断が出るのを
      -- 防ぐ。ここに無い linter は無条件で走る。第 2 引数は lint 対象の root。
      local gates = {
        biomejs = project.uses_biome,
        golangcilint = function(bufnr)
          return project.root_has(bufnr, {
            ".golangci.yml",
            ".golangci.yaml",
            ".golangci.toml",
            ".golangci.json",
          })
        end,
        -- haml_lint は nixpkgs に無いのでグローバルには置かない。Gemfile に
        -- 入っていないなら、そのプロジェクトは haml を lint しない方針だと
        -- 見なす（rubocop と同じ扱い）。実行ファイルの有無ではなく方針で判断
        -- するので、グローバルや mise.local.toml に入れても走らせない。
        haml_lint = function(_, dir)
          return dir ~= nil and project.bundles(dir, "haml_lint")
        end,
      }

      -- lint 対象の root。mise にプロジェクト設定を探索させる起点になる。
      local root_markers = {
        "Gemfile",
        "go.mod",
        "mise.toml",
        ".tool-versions",
        ".git",
      }

      local function run(bufnr)
        local ft = vim.bo[bufnr].filetype

        if
          vim.tbl_contains({
            "codecompanion",
            "pane-tabs-ai",
            "snacks_terminal",
            "terminal",
            "prompt",
          }, ft)
        then
          return
        end

        if vim.api.nvim_buf_get_name(bufnr) == "" then
          return
        end

        local names = lint.linters_by_ft[ft] or {}
        if #names == 0 then
          return
        end

        local dir = mise.dir(vim.fs.root(bufnr, root_markers))

        lint.try_lint(names, {
          cwd = dir,
          filter = function(linter)
            local gate = gates[linter.name]
            return gate == nil or gate(bufnr, dir)
          end,
          -- linter.cwd / linter.env は静的値しか取れないため、プロジェクト依存の
          -- 差し込みは try_lint 側から行う。
          wrap_linter = function(linter)
            return mise.linter(linter, dir, { haml_lint = "haml_lint" })
          end,
        })
      end

      local group = vim.api.nvim_create_augroup("uvu-lint", { clear = true })

      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
        group = group,
        callback = function(args)
          run(args.buf)
        end,
      })

      -- このプラグインは BufReadPost で遅延ロードされるため、ロードの契機になった
      -- 最初のバッファには上の autocmd が間に合わない（登録前にイベントが過ぎる）。
      -- 開いた直後に lint されないのを避けるため、既存バッファを一度走らせる。
      -- schedule するのは、この時点では filetype 検出（FileType）がまだ済んで
      -- おらず、ft が空だと linters_by_ft を引けないため。
      vim.schedule(function()
        for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(bufnr) then
            run(bufnr)
          end
        end
      end)
    end,
  },
}
