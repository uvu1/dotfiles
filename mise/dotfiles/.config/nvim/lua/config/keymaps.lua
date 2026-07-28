local function opts(desc)
  return { noremap = true, silent = true, desc = desc }
end

-- window navigation（<Cmd> は端末モードでも動くので {n,t} に一度で張れる）
vim.keymap.set({ "n", "t" }, "<C-h>", "<Cmd>wincmd h<CR>", opts("move to left window"))
vim.keymap.set({ "n", "t" }, "<C-l>", "<Cmd>wincmd l<CR>", opts("move to right window"))
vim.keymap.set({ "n", "t" }, "<C-j>", "<Cmd>wincmd j<CR>", opts("move to lower window"))
vim.keymap.set({ "n", "t" }, "<C-k>", "<Cmd>wincmd k<CR>", opts("move to upper window"))

-- LSP inline completion (Neovim 0.12 native)
vim.keymap.set("i", "<C-c>", function()
  if vim.lsp.inline_completion then
    return vim.lsp.inline_completion.get()
  end
end)

-- clear search highlight
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", opts("Clear search highlights"))

require("config.keymaps.contest")
