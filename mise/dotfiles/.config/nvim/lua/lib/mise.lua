-- サーバ本体は nix profile（nix/home.nix）に置き、解析対象のツールチェーンだけを
-- プロジェクトの設定（mise.toml / .tool-versions / .ruby-version / .node-version /
-- Gemfile）から取るための層。LSP と nvim-lint が同じ規則を共有する。
--
-- なぜ必要か: nvim の PATH は起動した時点の 1 つのディレクトリで解決済みで、
-- 以後変わらない。裸のコマンド名はその解決に固定されるので、バッファごと・root
-- ごとの切り替えが起きない（起動場所がプロジェクト内ならその版に、外なら nix の
-- フォールバックに張り付く）。`mise x -C <root>` だけがそれを覆せる。
--
-- 検証済み: `mise x -C <dir> -- printf ABC` の stdout は正確に "ABC" のみ。
-- 診断は stderr に出るので JSON-RPC を壊さない。また `mise x` は継承した PATH の
-- うち mise 管理外のエントリを保つので、nix profile のサーバ本体は掴めたままになる。
local M = {}

-- 未導入のツールチェーンを黙ってインストールさせない。エディタ内で数分ブロック
-- するより即失敗させる（mise の既定は exec_auto_install = true）。
local FAIL_FAST = {
  MISE_EXEC_AUTO_INSTALL = "0",
  MISE_NOT_FOUND_AUTO_INSTALL = "0",
}

--- `mise x` に渡す PATH の土台。
---
--- sheldon は mise を hook-env モード（`mise activate zsh`）で有効化するので、nvim が
--- 継承する PATH には既に「nvim を起動したディレクトリ」の installs が前置されている。
--- その PATH をそのまま渡して `mise x -C <別の root>` を呼ぶと、mise は前置済みの分を
--- 解決対象から外したうえで対象 root のツールを再付与しないため、プロジェクトの処理系が
--- 子プロセスに渡らない（実測: python を宣言した root でも nix のフォールバックに落ちた）。
--- activate 前の PATH は mise 自身が __MISE_ORIG_PATH に保存しているので、それを土台に
--- 渡して mise に一から解決させる。GUI 起動など activate を通っていない場合は未設定
--- なので、その時は継承した PATH をそのまま使う。
--- @return string
local function base_path()
  local orig = vim.env.__MISE_ORIG_PATH

  if type(orig) == "string" and orig ~= "" then
    return orig
  end

  return vim.env.PATH
end

--- @param path string|nil
--- @return boolean
local function is_dir(path)
  if type(path) ~= "string" or path == "" then
    return false
  end

  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

--- mise に設定を探索させるディレクトリ。単体ファイルでは root_dir が nil に
--- なりうる。LSP の transport は cwd がディレクトリであることを assert する
--- （`$VIMRUNTIME/lua/vim/lsp/_transport.lua`）ので実在を必ず確かめる。
--- @param root_dir string|nil
--- @return string|nil
function M.dir(root_dir)
  if is_dir(root_dir) then
    return root_dir
  end

  local cwd = vim.uv.cwd()
  return is_dir(cwd) and cwd or nil
end

--- @return boolean
function M.available()
  return vim.fn.executable("mise") == 1
end

--- `mise x -C <dir> -- <argv...>`。dir が無い、または mise が無い場合は素の argv。
--- @param argv string[]
--- @param dir string|nil
--- @return string[]
function M.argv(argv, dir)
  if not dir or not M.available() then
    return argv
  end

  return vim.list_extend({ "mise", "x", "-C", dir, "--" }, argv)
end

--- 起動直後の異常終了を通知する。mise の stderr は :LspLog にしか出ないため、
--- 即失敗を選んだ以上「サーバが黙って居ない」状態を見えるようにする必要がある。
--- @param dispatchers table
--- @param label string
--- @param dir string|nil
--- @return table
local function notify_early_exit(dispatchers, label, dir)
  local on_exit = dispatchers and dispatchers.on_exit
  if not on_exit then
    return dispatchers
  end

  local started = vim.uv.hrtime()

  return vim.tbl_extend("force", dispatchers, {
    on_exit = function(code, signal)
      -- on_exit は fast event context で呼ばれるので notify は schedule する。
      if code ~= 0 and vim.uv.hrtime() - started < 5e9 then
        vim.schedule(function()
          vim.notify(
            ("%s が起動できなかった (exit %d)。`mise x -C %s -- %s` を手で実行して原因を見る。"):format(
              label,
              code,
              vim.fn.fnamemodify(dir or ".", ":~"),
              label
            )
              .. " 未導入なら mise install、mise.toml が untrusted なら mise trust。詳細は :LspLog。",
            vim.log.levels.ERROR
          )
        end)
      end

      on_exit(code, signal)
    end,
  })
end

--- @class lib.mise.LspOpts
--- @field local_bin? string root 直下で優先探索するディレクトリ（例 "node_modules/.bin"）
--- @field bundled? string Gemfile.lock に載っていれば bundle exec 経由にする gem 名
--- @field env? table<string, string> 追加の環境変数

--- `vim.lsp.config` の `cmd` 関数を作る。root_dir 解決後に呼ばれるので、
--- プロジェクト単位の分岐をここに書ける。
--- @param argv string[]
--- @param opts lib.mise.LspOpts|nil
--- @return function
function M.lsp_cmd(argv, opts)
  opts = opts or {}

  return function(dispatchers, config)
    config = config or {}
    local dir = M.dir(config.cmd_cwd or config.root_dir)
    local label = argv[1]
    local resolved = vim.list_slice(argv)

    -- nvim-lspconfig の一部サーバは cmd 関数で node_modules/.bin を優先する。
    -- cmd を差し替えるとその挙動が消えるので、同じ規則をここに持つ。
    if dir and opts.local_bin then
      local candidate = vim.fs.joinpath(dir, opts.local_bin, label)
      if vim.fn.executable(candidate) == 1 then
        resolved[1] = candidate
      end
    end

    -- gem はプロジェクトの Gemfile に載っている方が正しい（設定が参照する
    -- plugin gem はそこにしか無い）。node_modules/.bin と同じ発想。
    if dir and opts.bundled and require("lib.project").bundles(dir, opts.bundled) then
      resolved = vim.list_extend({ "bundle", "exec" }, resolved)
    end

    -- vim.lsp.rpc.start の env は base_env() とのマージなのでキーの削除はできないが、
    -- PATH の上書きはできる。それだけで mise に一から解決させられる。
    return vim.lsp.rpc.start(M.argv(resolved, dir), notify_early_exit(dispatchers, label, dir), {
      cwd = dir,
      env = vim.tbl_extend("force", FAIL_FAST, { PATH = base_path() }, opts.env or {}),
    })
  end
end

--- `uv.spawn` に渡す環境。nvim-lint の env と nvim-dap の
--- `dap.ExecutableAdapter.options.env` はどちらも uv.spawn の env（＝環境の置換）で、
--- vim.system と違ってマージされない。既存環境を明示的に持ち回らないと HOME や
--- GEM_* を失う。PATH は lsp_cmd と同じ理由で activate 前のものに戻す（base_path 参照）。
--- @param extra table<string, string>|nil
--- @return table<string, string>
function M.spawn_env(extra)
  return vim.tbl_extend("force", vim.fn.environ(), FAIL_FAST, { PATH = base_path() }, extra or {})
end

--- nvim-lint の linter を mise 経由に書き換える。`try_lint` の `wrap_linter` から
--- 呼ぶ（cmd / args の評価前に deepcopy に対して呼ばれる）。
--- @param linter table
--- @param dir string|nil
--- @param bundled table<string, string>|nil linter 名 → gem 名
--- @return table
function M.linter(linter, dir, bundled)
  -- 関数 cmd の linter は自前で解決しているので触らない。
  if not dir or not M.available() or type(linter.cmd) ~= "string" then
    return linter
  end

  local head = { "x", "-C", dir, "--" }
  local gem = bundled and bundled[linter.name]

  if gem and require("lib.project").bundles(dir, gem) then
    vim.list_extend(head, { "bundle", "exec" })
  end

  table.insert(head, linter.cmd)

  return vim.tbl_extend("force", linter, {
    cmd = "mise",
    args = vim.list_extend(head, linter.args or {}),
    env = M.spawn_env(),
  })
end

return M
