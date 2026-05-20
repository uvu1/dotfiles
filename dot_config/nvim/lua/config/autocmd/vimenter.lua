vim.api.nvim_create_autocmd("VimEnter", {
  callback = function ()
    if vim.fn.argc() > 0 then
      return
    end

    vim.schedule(function ()
      local snacks = require("snacks")
      snacks.explorer.open({
        focus = "list",
        enter = true,
        auto_close = false,
        layout = {
          preset = "sidebar",
          preview = false,
          hidden = { "input" },
        }
      })
    end)
  end
})
