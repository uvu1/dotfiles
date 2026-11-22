-- 構文選択（vaf/dif 等）だけを提供する。前後移動は標準 ftplugin に任せる。
-- af/if/ac/ic は同梱 ftplugin と衝突しないため vim.g.no_plugin_maps は設定しない。
local function select(query)
  return function()
    require("nvim-treesitter-textobjects.select").select_textobject(query, "textobjects")
  end
end

return {
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      select = { lookahead = true },
    },
    keys = {
      { "af", select("@function.outer"), mode = { "x", "o" }, desc = "a function" },
      { "if", select("@function.inner"), mode = { "x", "o" }, desc = "inner function" },
      { "ac", select("@class.outer"), mode = { "x", "o" }, desc = "a class" },
      { "ic", select("@class.inner"), mode = { "x", "o" }, desc = "inner class" },
      { "aa", select("@parameter.outer"), mode = { "x", "o" }, desc = "a parameter" },
      { "ia", select("@parameter.inner"), mode = { "x", "o" }, desc = "inner parameter" },
    },
  },
}
