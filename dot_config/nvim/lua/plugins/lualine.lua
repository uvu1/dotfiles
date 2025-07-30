return {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = true,
    event = { "BufReadPre", "BufNewFile" },
}
