-- 関数（メソッド）とクラスの前後移動を LSP が付いたバッファにだけ張る。
--
-- グローバルマップにできない理由: 同梱 ftplugin の 21 個ほど（python, rust, go,
-- php, ruby, markdown, vim など）が ]] [[ ]m [m をバッファローカルで定義しており、
-- バッファローカルが常にグローバルより優先される。ftplugin より後に走る LspAttach
-- で同じバッファローカルとして上書きすることで初めて勝てる。

local utils = require("config.keymap.utils")

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

    -- copilot は全 filetype に attach するが documentSymbol を持たない。
    -- シンボルを出せるサーバが付いたときだけ張り、それ以外では ftplugin や
    -- 既定の挙動をそのまま残す。
    if not client or not client:supports_method("textDocument/documentSymbol") then
      return
    end

    for _, key in ipairs(keys) do
      local lhs, method, desc = key[1], key[2], key[3]
      local opts = utils.opts(desc)

      opts.buffer = args.buf

      utils.keymap.vim("n", lhs, function()
        require("config.symbol-nav")[method]()
      end, opts)
    end
  end,
})
