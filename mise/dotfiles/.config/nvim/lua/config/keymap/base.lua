local utils = require("config.keymap.utils")

utils.keymap.vim("n", "<C-h>", "<C-w>h", utils.opts("move to left"))
utils.keymap.vim("n", "<C-l>", "<C-w>l", utils.opts("move to right"))
utils.keymap.vim("n", "<C-j>", "<C-w>j", utils.opts("move to upper"))
utils.keymap.vim("n", "<C-k>", "<C-w>k", utils.opts("move to lower"))
utils.keymap.vim("i", "<C-c>", function ()
  if vim.lsp.inline_completion then
    return vim.lsp.inline_completion.get()
  end
end)

utils.keymap.vim("n", "<Esc>", "<cmd>nohlsearch<CR>", utils.opts("Clear search highlights"))
