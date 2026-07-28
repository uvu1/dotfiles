return {
  {
    "stevearc/aerial.nvim",
    -- ]m/[m と ]]/[[ は aerial が保持するシンボルツリーを引く（lib/symbol-nav）。
    -- keys 遅延だけだと初回押下時にまだバックエンドが attach しておらずシンボルが
    -- 空になるので、LSP が付いた時点でロードしておく。
    event = "LspAttach",
    opts = {
      -- aerial は on_attach も open_automatic も無いと lazy_load = true と判定し、
      -- サイドバーを開くまでシンボルを取りに行かない。サイドバー無しで使うので
      -- 明示的に無効化し、LSP attach 時点でシンボルを保持させる。
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
    keys = {
      { "<leader>o", "<cmd>AerialToggle!<cr>", desc = "Toggle Aerial" },
    },
  },
}
