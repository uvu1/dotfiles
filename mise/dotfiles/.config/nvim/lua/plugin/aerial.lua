return {
  {
    "stevearc/aerial.nvim",
    -- ]m/[m と ]]/[[ は aerial が保持するシンボルツリーを引く。keys 遅延だけだと
    -- 初回押下時にまだバックエンドが attach しておらずシンボルが空になるので、
    -- LSP が付いた時点でロードしておく。
    event = "LspAttach",
    opts = {
      -- aerial は on_attach も open_automatic も無いと lazy_load = true と判定し、
      -- autocmd を作らずサイドバーを開くまでシンボルを取りに行かない
      -- （aerial/init.lua の setup）。]m/[m と ]]/[[ はサイドバーを開かずに使うので
      -- 明示的に無効化して、LSP attach 時点でシンボルを保持させる。
      lazy_load = false,

      backends = { "lsp", "treesitter", "markdown" },
      filter_kind = {
        "Class",
        "Constructor",
        "Enum",
        "Function",
        "Interface",
        "Module",
        "Method",
        "Struct",
      },
      show_guides = true,
      layout = {
        default_direction = "prefer_right",
        max_width = 40,
        min_width = 20,
        placement = "window",
      },
    },
    keys = function() return require("config.keymap.plugins.aerial") end,
  }
}
