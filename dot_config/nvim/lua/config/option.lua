vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.termguicolors = true
vim.opt.wrap = false
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"

vim.opt.pumblend = 10
vim.opt.winblend = 10

vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.smartindent = true

vim.opt.updatetime = 300

vim.opt.clipboard = "unnamedplus"

vim.opt.ignorecase = true
vim.opt.smartcase = true

vim.opt.splitbelow = true
vim.opt.splitright = true

-- for WSL 
if vim.fn.has("wsl") == 1 then
  if vim.fn.executable("wl-copy") == 0 then
    print("wl-copy is not installed, clipboard integration will not work")
  else
    vim.g.clipboard = {
      name = "wl-clipboard(wsl)",
      copy = {
        ["+"] = "wl-copy --foreground --type text/plain",
        ["*"] = "wl-copy --foreground --primary --type text/plain",
      },
      paste = {
        ["+"] =(function()
          return vim.fn.systemlist('wl-paste --no-newline|sed -e "s/\r$//"', {''}, 1)
        end),
        ["*"] = (function ()
          return vim.fn.systemlist('wl-paste --no-newline --primary|sed -e "s/\r$//"', {''}, 1)
        end),
      },
       cache_enabled = true,
    }
  end
end
