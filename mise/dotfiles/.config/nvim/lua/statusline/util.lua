local M = {}

function M.trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function M.refresh_statusline()
  local ok, lualine = pcall(require, "lualine")

  if ok and type(lualine.refresh) == "function" then
    lualine.refresh({
      force = true,
      place = { "statusline" },
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
