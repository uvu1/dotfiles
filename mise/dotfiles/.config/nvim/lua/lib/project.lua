-- プロジェクトルート方向の設定ファイル探索。conform / nvim-lint の双方が
-- 「この buffer はどのツールの設定下にいるか」を同じ基準で判断するために使う。
local M = {}

--- Directory to start an upward search from, for the given buffer.
--- @param bufnr integer
--- @return string|nil
local function search_dir(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return nil
  end

  return vim.fs.dirname(path)
end

--- True if any of `names` exists at or above the buffer's directory.
--- @param bufnr integer
--- @param names string[]
--- @return boolean
function M.root_has(bufnr, names)
  local dir = search_dir(bufnr)
  if not dir then
    return false
  end

  local found = vim.fs.find(names, {
    path = dir,
    upward = true,
    type = "file",
    stop = vim.uv.os_homedir(),
  })

  return #found > 0
end

--- True if a file named `names` at or above the buffer's directory contains
--- `pattern` (plain substring). Used for `package.json` style declarations.
--- @param bufnr integer
--- @param names string[]
--- @param pattern string
--- @return boolean
function M.root_file_contains(bufnr, names, pattern)
  local dir = search_dir(bufnr)
  if not dir then
    return false
  end

  local found = vim.fs.find(names, {
    path = dir,
    upward = true,
    type = "file",
    stop = vim.uv.os_homedir(),
  })

  for _, file in ipairs(found) do
    local ok, lines = pcall(vim.fn.readfile, file)
    if ok then
      for _, line in ipairs(lines) do
        if line:find(pattern, 1, true) then
          return true
        end
      end
    end
  end

  return false
end

--- True if the buffer belongs to a project configured for biome.
--- nvim-lspconfig の `lsp/biome.lua` と同じ判定（設定ファイル、または
--- package.json の biomejs 宣言）に揃えている。LSP・formatter・linter で
--- biome の適用範囲が食い違わないようにするのが目的。
--- @param bufnr integer
--- @return boolean
function M.uses_biome(bufnr)
  return M.root_has(bufnr, { "biome.json", "biome.jsonc" })
    or M.root_file_contains(bufnr, { "package.json", "package.json5" }, "biomejs")
end

--- True if `dir` の Gemfile.lock が `gem` を含む。bundle exec 経由で起動すべきか
--- の判定に使う。gem 系ツールはインストール時の ruby に紐づくため、プロジェクト
--- の bundle にあるならそちらを使う方が確実。
--- bufnr ではなく dir を取るのは、LSP の cmd と nvim-lint の wrap_linter が
--- どちらも root ディレクトリしか持たないため。
--- @param dir string
--- @param gem string
--- @return boolean
function M.bundles(dir, gem)
  local ok, lines = pcall(vim.fn.readfile, vim.fs.joinpath(dir, "Gemfile.lock"))
  if not ok then
    return false
  end

  local pattern = "^%s+" .. vim.pesc(gem) .. "%s"
  for _, line in ipairs(lines) do
    if line:match(pattern) then
      return true
    end
  end

  return false
end

--- True if the buffer belongs to a project configured for prettier.
--- @param bufnr integer
--- @return boolean
function M.uses_prettier(bufnr)
  return M.root_has(bufnr, {
    "prettier.config.js",
    "prettier.config.mjs",
    "prettier.config.cjs",
    ".prettierrc",
    ".prettierrc.json",
    ".prettierrc.js",
    ".prettierrc.cjs",
    ".prettierrc.mjs",
    ".prettierrc.yaml",
    ".prettierrc.yml",
    ".prettierrc.toml",
  })
end

return M
