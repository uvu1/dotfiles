return {
    {
        'akinsho/bufferline.nvim',
        version = "*",
        dependencies = 'nvim-tree/nvim-web-devicons',
        config = true,
        keys = {
            { "<C-l>", "<cmd>BufferLineCycleNext<CR>", },
            { "<C-h>", "<cmd>BufferLineCyclePrev<CR>", },
        },
        event = { "BufNewFile", "BufRead" },
    }
}
