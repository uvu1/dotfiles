local M = {}
local excluded = { snacks_terminal = true, terminal = true, prompt = true }

-- 整形・lint・自動保存が扱う通常ファイル。サイズや書込可否は呼出元で判断する。
function M.is_file(bufnr)
  return vim.bo[bufnr].buftype == "" and not excluded[vim.bo[bufnr].filetype] and vim.api.nvim_buf_get_name(bufnr) ~= ""
end

return M
