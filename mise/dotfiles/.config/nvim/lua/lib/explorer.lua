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
      picker:focus("list")
      return
    end
  end

  snacks.explorer.open(vim.tbl_extend("keep", opts or {}, { focus = "list" }))
end

return M
