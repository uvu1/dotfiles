-- 引数なし起動時はExplorerを開く。標準SSHの新規セッションは先に作業場所を選ぶ。
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() > 0 then
      return
    end

    vim.schedule(function()
      local explorer = require("lib.explorer")
      if vim.env.NVIM_APPNAME == "nvim-remote" then
        explorer.choose_directory()
      else
        explorer.focus_or_open({ enter = true })
      end
    end)
  end,
})

-- auto-save.nvim の置換。InsertLeave 連発（保存＋フォーマットが走る）をやめ、
-- バッファを離れる/フォーカスを失うタイミングでのみ保存する。
-- autowriteall で :next / :make 等の暗黙保存も有効化。
vim.o.autowriteall = true

vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
  group = vim.api.nvim_create_augroup("auto-save", { clear = true }),
  callback = function(args)
    local buf = args.buf

    if
      not require("lib.buffer").is_file(buf)
      or not vim.bo[buf].modifiable
      or not vim.bo[buf].modified
      or vim.bo[buf].readonly
    then
      return
    end

    local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
      vim.cmd("silent update")
    end)
    if not ok then
      vim.notify("自動保存に失敗しました: " .. tostring(err), vim.log.levels.ERROR)
    end
  end,
})
