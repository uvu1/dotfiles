-- 関数（メソッド）とクラスの前後移動。
--
-- シンボルは aerial から取る。aerial は backends = { "lsp", "treesitter", "markdown" }
-- で自動的にバッファへ追従しており、LSP が attach していれば LSP のシンボルツリーが
-- そのまま入る。自前で textDocument/documentSymbol を投げるとキャッシュと
-- DocumentSymbol / SymbolInformation の差異を扱う必要があるので、aerial の結果を使う。

local M = {}

-- aerial の kind は LSP SymbolKind 名に正規化されている。
-- lua/plugin/aerial.lua の filter_kind に含まれるものだけが data に載る点に注意。
local FUNCTION_KINDS = {
  Function = true,
  Method = true,
  Constructor = true,
}

-- 「クラス」は言語ごとに等価物が違うので、メンバを持つ型定義をまとめて扱う
-- （Rust の struct / enum、TypeScript の interface など）。
local CLASS_KINDS = {
  Class = true,
  Interface = true,
  Struct = true,
  Enum = true,
}

--- aerial がジャンプ先に使う位置。selection_range があればシンボル名の位置、
--- 無ければ宣言全体の開始位置。比較にも同じ値を使わないと連打で止まる。
--- @param item aerial.Symbol
--- @return integer lnum
--- @return integer col
local function position(item)
  local range = item.selection_range

  if range then
    return range.lnum, range.col
  end

  return item.lnum, item.col
end

--- @param kinds table<string, boolean>
--- @return aerial.Symbol[]|nil
local function symbols(kinds)
  local ok, data = pcall(require, "aerial.data")

  if not ok or not data.has_symbols(0) then
    return nil
  end

  local matched = {}

  -- メソッドはクラスの子なので、トップレベルだけでなくツリー全体を辿る。
  data.get_or_create(0):visit(function(item)
    if kinds[item.kind] then
      table.insert(matched, item)
    end
  end)

  table.sort(matched, function(a, b)
    local a_lnum, a_col = position(a)
    local b_lnum, b_col = position(b)

    if a_lnum ~= b_lnum then
      return a_lnum < b_lnum
    end

    return a_col < b_col
  end)

  return matched
end

--- @param kinds table<string, boolean>
--- @param step integer 1 で次へ、-1 で前へ
--- @param label string 見つからなかったときの通知に使う
local function jump(kinds, step, label)
  local matched = symbols(kinds)

  if not matched then
    vim.notify("Symbols not ready yet", vim.log.levels.WARN)
    return
  end

  if #matched == 0 then
    vim.notify("No " .. label .. " in this buffer", vim.log.levels.WARN)
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(0)
  local lnum, col = cursor[1], cursor[2]
  local target

  if step > 0 then
    for _, item in ipairs(matched) do
      local item_lnum, item_col = position(item)

      if item_lnum > lnum or (item_lnum == lnum and item_col > col) then
        target = item
        break
      end
    end
  else
    for i = #matched, 1, -1 do
      local item = matched[i]
      local item_lnum, item_col = position(item)

      if item_lnum < lnum or (item_lnum == lnum and item_col < col) then
        target = item
        break
      end
    end
  end

  -- 端まで来たら反対側へ回り込む（aerial の next/prev と同じ挙動）。
  if not target then
    target = step > 0 and matched[1] or matched[#matched]
  end

  -- jumplist への記録・post_jump_cmd・highlight_on_jump は aerial 側が面倒を見る。
  require("aerial.navigation").select_symbol(target, vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf(), {
    jump = true,
  })
end

function M.next_function()
  jump(FUNCTION_KINDS, 1, "function")
end

function M.prev_function()
  jump(FUNCTION_KINDS, -1, "function")
end

function M.next_class()
  jump(CLASS_KINDS, 1, "class")
end

function M.prev_class()
  jump(CLASS_KINDS, -1, "class")
end

return M
