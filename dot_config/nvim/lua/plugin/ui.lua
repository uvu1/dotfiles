local function set_transparent_background()
  local groups = {
    "Normal",
    "NormalNC",
    "NormalFloat",
    "FloatBorder",
    "SignColumn",
    "LineNr",
    "CursorLineNr",
    "EndOfBuffer",

    "SnacksPicker",
    "SnacksPickerBorder",
    "SnacksPickerTitle",
    "SnacksPickerBoxTitle",

    "SnacksPickerInput",
    "SnacksPickerInputBorder",
    "SnacksPickerInputTitle",
  }

  for _, group in ipairs(groups) do
    vim.api.nvim_set_hl(0, group, { bg = "NONE"} )
  end
end

return {
  {
    -- "uvu1/kawaii-theme.nvim",
    dir = vim.fn.expand("~/repo/github.com/uvu/kawaii-theme.nvim"),
    name = "kawaii-theme.nvim",
    lazy = false,
    priority = 1000,
    config = function ()
      require("kawaii-theme").setup({
        transparent = true
      })
      vim.cmd.colorscheme("kawaii-theme")
    end,
  },
}
