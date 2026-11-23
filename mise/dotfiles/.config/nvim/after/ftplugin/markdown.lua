-- 標準 ftplugin は comments の f フラグ（leader を次行へ繰り返さない）と
-- formatoptions-=r,o で箇条書きを継続しない。<CR>（r）と o/O（o）で
-- - * + と引用 > を次行へ引き継ぐよう上書きする。
vim.opt_local.comments = { "b:-", "b:*", "b:+", "n:>" }
vim.opt_local.formatoptions:append("ro")
