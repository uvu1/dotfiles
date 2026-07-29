local M = {}

function M.trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function M.refresh_statusline()
  local ok, lualine = pcall(require, "lualine")

  if ok and type(lualine.refresh) == "function" then
    -- winbar も同じ更新サイクルに乗せる。パンくず（statusline.winbar）は
    -- lualine 側の 1000ms タイマ任せだと古い symbol を出し続ける。
    lualine.refresh({
      force = true,
      place = { "statusline", "winbar" },
      scope = "tabpage",
    })
    return
  end

  vim.cmd.redrawstatus()
end

function M.pill(component, opts)
  opts = opts or {}

  return vim.tbl_extend("force", {
    component,
    separator = { left = "", right = "" },
    padding = { left = 1, right = 1 },
  }, opts)
end

return M
