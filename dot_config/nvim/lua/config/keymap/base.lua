local keymap = vim.keymap.set

--- return options
--- @param desc string Description of keybind
local opts = function (desc)
 return {
   noremap = true,
   silent = true,
   desc = desc
 }
end

keymap("n", "<C-h>", "<C-w>h", opts("move to left"))
keymap("n", "<C-l>", "<C-w>l", opts("move to right"))
keymap("n", "<C-j>", "<C-w>j", opts("move to upper"))
keymap("n", "<C-k>", "<C-w>k", opts("move to lower"))
keymap("i", "<C-c>", function ()
  if vim.lsp.inline_completion then
    return vim.lsp.inline_completion.get()
  end
end)

keymap("n", "<Esc>", "<cmd>nohlsearch<CR>", opts("Clear search highlights"))

return {
  keymap = keymap,
  opts = opts,
}
