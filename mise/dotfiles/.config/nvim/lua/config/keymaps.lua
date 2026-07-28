local function opts(desc)
  return { noremap = true, silent = true, desc = desc }
end

-- window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", opts("move to left window"))
vim.keymap.set("n", "<C-l>", "<C-w>l", opts("move to right window"))
vim.keymap.set("n", "<C-j>", "<C-w>j", opts("move to lower window"))
vim.keymap.set("n", "<C-k>", "<C-w>k", opts("move to upper window"))

-- LSP inline completion (Neovim 0.12 native)
vim.keymap.set("i", "<C-c>", function()
  if vim.lsp.inline_completion then
    return vim.lsp.inline_completion.get()
  end
end)

-- clear search highlight
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", opts("Clear search highlights"))

require("config.keymaps.contest")
