-- gitsigns は blame ペインを `aboveleft vsplit` で開き、位置を設定で変えられない
-- （gitsigns/actions/blame.lua）。filetype が付いた直後＝gitsigns が scrollbind を
-- 張る前に、下部の横分割へ移し替える。
vim.cmd("wincmd J")
vim.api.nvim_win_set_height(0, 12)
vim.opt_local.winfixheight = true
