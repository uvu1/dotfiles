return {
    {
        "nvim-tree/nvim-tree.lua",
        keys = {
            { "<leader>et", "<cmd>NvimTreeToggle<cr>", desc = "Toggle NeoTree" },
            { "<leader>fe", "<cmd>NvimTreeFocus<cr>", desc = "Focus Neotree" },
            { "<leader>fb", "<cmd>NvimTreeFindFile<cr>", desc = "Move cursor to the file opening in buffer" }
        },
        opts = {
            update_focused_file = {
                enable = true,
                update_cwd =true,
            },
            filters = {
                custom = {".git"},
                exclude = {".gitignore"},
            },
        },
    }
}
