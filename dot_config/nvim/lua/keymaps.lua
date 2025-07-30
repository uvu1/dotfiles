vim.g.mapleader = " "
vim.keymap.set("n", "<LEADER>bd", "<CMD>%bd|e#|bd#<CR>|\'\"", { desc = "Close all buffers", })

