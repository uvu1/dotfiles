return {
  {
    "Pocco81/auto-save.nvim",
    opts = {
      condition = function(buf)
        if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
          return false
        end

        local bo = vim.bo[buf]

        if bo.buftype ~= "" or bo.filetype == "codecompanion" or bo.filetype == "pane-tabs-ai" then
          return false
        end

        if not bo.modifiable or bo.readonly then
          return false
        end

        return vim.api.nvim_buf_get_name(buf) ~= ""
      end,
    },
    event = "InsertLeave",
  }
}
