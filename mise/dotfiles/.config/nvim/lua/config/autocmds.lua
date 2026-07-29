-- 引数なし起動時に snacks explorer を自動オープン（旧 config/autocmd/vimenter.lua）
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() > 0 then
      return
    end

    vim.schedule(function()
      local ok, snacks = pcall(require, "snacks")
      if not ok then
        return
      end
      snacks.explorer.open({
        focus = "list",
        enter = true,
        auto_close = false,
        layout = {
          preset = "sidebar",
          preview = false,
          hidden = { "input" },
        },
      })
    end)
  end,
})

-- 関数/クラス移動（]m [m ]] [[）を LSP が付いたバッファにバッファローカルで張る。
-- グローバルだと同梱 ftplugin の 21 個ほど（python/rust/go/... ）が同じキーを
-- バッファローカルで定義しており負ける。ftplugin より後に走る LspAttach で上書きする。
do
  local keys = {
    { "]m", "next_function", "Go to next function/method" },
    { "[m", "prev_function", "Go to previous function/method" },
    { "]]", "next_class", "Go to next class" },
    { "[[", "prev_class", "Go to previous class" },
  }

  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("symbol-nav", { clear = true }),
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)

      -- documentSymbol を持たないサーバ（eslint / biome など）も attach するので、
      -- シンボルを出せるサーバが付いたときだけ張る。
      if not client or not client:supports_method("textDocument/documentSymbol") then
        return
      end

      for _, key in ipairs(keys) do
        local lhs, method, desc = key[1], key[2], key[3]
        vim.keymap.set("n", lhs, function()
          require("lib.symbol-nav")[method]()
        end, { noremap = true, silent = true, desc = desc, buffer = args.buf })
      end
    end,
  })
end

-- auto-save.nvim の置換。InsertLeave 連発（保存＋フォーマットが走る）をやめ、
-- バッファを離れる/フォーカスを失うタイミングでのみ保存する。
-- autowriteall で :next / :make 等の暗黙保存も有効化。
vim.o.autowriteall = true

vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost" }, {
  group = vim.api.nvim_create_augroup("auto-save", { clear = true }),
  callback = function(args)
    local buf = args.buf

    if vim.bo[buf].buftype ~= "" or not vim.bo[buf].modifiable or not vim.bo[buf].modified then
      return
    end

    if vim.api.nvim_buf_get_name(buf) == "" then
      return
    end

    pcall(vim.api.nvim_buf_call, buf, function()
      vim.cmd("silent! update")
    end)
  end,
})
