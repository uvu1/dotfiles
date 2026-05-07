local severity = vim.diagnostic.severity

vim.diagnostic.config({
  virtual_lines = false,

  virtual_text = {
    virt_text_pos = "inline",
    source = "if_many",
    spacing = 1,
    prefix = function(diagnostic)
      local icons = {
        [severity.ERROR] = "󰅚 ",
        [severity.WARN] = "󰀪 ",
        [severity.INFO] = "󰋽 ",
        [severity.HINT] = "󰌶 ",
      }
      return icons[diagnostic.severity] or "● "
    end,
    format = function(diagnostic)
      local msg = diagnostic.message:gsub("\n", " ")
      if #msg > 100 then
        msg = msg:sub(1, 97) .. "..."
      end
      return msg
    end,
  },

  signs = {
    text = {
      [severity.ERROR] = "󰅚",
      [severity.WARN] = "󰀪",
      [severity.INFO] = "󰋽",
      [severity.HINT] = "󰌶",
    },
  },

  underline = true,
  update_in_insert = false,
  severity_sort = true,

  float = {
    border = "rounded",
    source = true,
  },
})

vim.o.winborder = "rounded"
