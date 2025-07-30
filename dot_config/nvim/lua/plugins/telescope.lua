return {
    {
        "nvim-telescope/telescope.nvim", 
        dependencies = {
            "nvim-lua/plenary.nvim",
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
        keys = {
            {"<leader>ff", "<cmd>Telescope find_files<cr>", desc="Telescope find_files"},
            {"<leader>fb", "<cmd>Telescope buffer<cr>", desc="Telescope buffer"},
            {"<leader>fg", "<cmd>Telescope live_grep<cr>", desc="Telescope live_grep"}
        }

    },

}
