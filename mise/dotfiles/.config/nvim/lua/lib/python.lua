-- Python インタプリタのプロジェクト単位の解決。nvim-dap の debugpy アダプタと
-- neotest-python が同じ規則を共有するための層。
--
-- なぜ lib/mise だけで足りないか: LSP（basedpyright）はサーバ本体が nix profile に
-- あり、プロジェクトを「読む」ために処理系を渡すだけなので mise x で足りる。
-- デバッグとテストはプロジェクトのコードを「実行する」ので、debugpy や pytest が
-- 入っている venv の python でなければならない。mise の python は venv 統合を
-- 宣言したプロジェクトでしか venv を指さないため、venv を先に見て、
-- 無いときだけ mise 経由に落とす。
local M = {}

local mise = require("lib.mise")

-- neotest-python の root 判定（lua/neotest-python/base.lua の match_root_pattern）
-- と同じ材料に揃える。adapter が attach する範囲とインタプリタの解決範囲が
-- 食い違うと「テストは見つかるのに実行できない」状態になる。
local ROOT_MARKERS = {
  "pyproject.toml",
  "setup.cfg",
  "mypy.ini",
  "pytest.ini",
  "setup.py",
}

local VENV_DIRS = { ".venv", "venv" }

--- @param bufnr integer|nil
--- @return string|nil
function M.root(bufnr)
  return vim.fs.root(bufnr or 0, ROOT_MARKERS)
end

--- python を起動する argv。有効化済み venv → プロジェクト直下の venv →
--- mise 経由の順に解決する。
--- @param dir string|nil プロジェクトルート
--- @return string[]
function M.argv(dir)
  local venvs = {}

  -- 有効化済みの venv が最優先。direnv や `source .venv/bin/activate` の下で
  -- nvim を起動した場合はそれが唯一の正解。
  if vim.env.VIRTUAL_ENV then
    table.insert(venvs, vim.env.VIRTUAL_ENV)
  end

  if dir then
    for _, name in ipairs(VENV_DIRS) do
      table.insert(venvs, vim.fs.joinpath(dir, name))
    end
  end

  for _, venv in ipairs(venvs) do
    local exe = vim.fs.joinpath(venv, "bin", "python")
    if vim.fn.executable(exe) == 1 then
      return { exe }
    end
  end

  return mise.argv({ "python" }, mise.dir(dir))
end

return M
