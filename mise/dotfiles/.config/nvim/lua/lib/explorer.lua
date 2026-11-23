-- explorer の入口。VimEnter の自動オープン（config/autocmds.lua）と
-- <leader>e（plugins/snacks.lua）が同じ経路を通る。
--
-- レイアウトと auto_close は plugins/snacks.lua の picker.sources.explorer が
-- 正本なので、呼び出し側では指定しない（explorer.open は source 設定に
-- マージされる）。以前は同じ sidebar レイアウトの table が 3 箇所に散っていた。
local M = {}

---開いている explorer があればそこへフォーカスし、無ければ開く。
---@param opts? table snacks.explorer.open に渡す追加オプション
function M.focus_or_open(opts)
  local ok, snacks = pcall(require, "snacks")
  if not ok then
    return
  end

  for _, picker in ipairs(snacks.picker.get({ source = "explorer" })) do
    if not picker.closed then
      if opts and opts.cwd then
        picker:set_cwd(opts.cwd)
        picker:find()
      end
      picker:focus("list")
      return
    end
  end

  snacks.explorer.open(vim.tbl_extend("keep", opts or {}, { focus = "list" }))
end

---現在のホストのフォルダを一覧から選び、作業場所とExplorerを揃える。
---接続先自身のファイルシステムを読み、SSH通信は追加しない。
function M.choose_directory()
  local function browse(dir)
    local scan, err = vim.uv.fs_scandir(dir)
    if not scan then
      vim.notify("フォルダを読み取れません: " .. tostring(err), vim.log.levels.ERROR)
      return
    end

    local children = {}
    while true do
      local name, kind = vim.uv.fs_scandir_next(scan)
      if not name then
        break
      end
      local path = vim.fs.joinpath(dir, name)
      if kind == "directory" or (kind == "link" and vim.fn.isdirectory(path) == 1) then
        children[#children + 1] = { path = path, label = name .. "/" }
      end
    end
    table.sort(children, function(a, b)
      return a.label < b.label
    end)

    local items = { { path = dir, label = "このフォルダを使う", accept = true } }
    local parent = vim.fs.dirname(dir)
    if parent and parent ~= dir then
      items[#items + 1] = { path = parent, label = "../（親フォルダ）" }
    end
    vim.list_extend(items, children)

    vim.ui.select(items, {
      prompt = "作業フォルダ: " .. dir,
      format_item = function(item)
        return item.label
      end,
    }, function(item)
      if not item then
        return
      end
      if not item.accept then
        browse(item.path)
        return
      end
      local ok, message = pcall(vim.api.nvim_set_current_dir, item.path)
      if not ok then
        vim.notify("作業フォルダを変更できません: " .. tostring(message), vim.log.levels.ERROR)
        return
      end
      M.focus_or_open({ cwd = item.path, enter = true })
    end)
  end

  browse(vim.fn.getcwd())
end

return M
