local function opts(desc)
  return { noremap = true, silent = true, desc = desc }
end

-- window navigation（<Cmd> は端末モードでも動くので {n,t} に一度で張れる）
vim.keymap.set({ "n", "t" }, "<C-h>", "<Cmd>wincmd h<CR>", opts("move to left window"))
vim.keymap.set({ "n", "t" }, "<C-l>", "<Cmd>wincmd l<CR>", opts("move to right window"))
vim.keymap.set({ "n", "t" }, "<C-j>", "<Cmd>wincmd j<CR>", opts("move to lower window"))
vim.keymap.set({ "n", "t" }, "<C-k>", "<Cmd>wincmd k<CR>", opts("move to upper window"))

-- clear search highlight
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", opts("Clear search highlights"))

-- UI トグル（<leader>u）。Snacks.toggle:map() が which-key のアイコン・色・
-- 説明の反転まで面倒を見るので vim.keymap.set は使わない。
-- snacks は lazy = false、Snacks は遅延 __index のグローバルなので、
-- init.lua が config.lazy の後にこのファイルを require している時点で安全。
-- codelens と document_color には組込みトグルが無いが、
-- vim.lsp.<mod>.is_enabled/enable が同形なので生成側で吸収する。
local function lsp_toggle(mod, name)
  return Snacks.toggle.new({
    id = mod,
    name = name,
    get = function()
      return vim.lsp[mod].is_enabled({ bufnr = 0 })
    end,
    set = function(state)
      vim.lsp[mod].enable(state, { bufnr = 0 })
    end,
  })
end

Snacks.toggle.inlay_hints():map("<leader>uh")
Snacks.toggle.diagnostics():map("<leader>ud")
Snacks.toggle.indent():map("<leader>ug")
Snacks.toggle.option("wrap"):map("<leader>uw")
Snacks.toggle.words():map("<leader>uo")
lsp_toggle("codelens", "CodeLens"):map("<leader>ul")
lsp_toggle("document_color", "Document Colors"):map("<leader>uc")

require("config.keymaps.contest")
