return {
    {
        "nat-418/boole.nvim",
        opts = {
            mappings = {
                increment = "<C-a>",
                decrement = "<C-x>",
            },
        },
        event = "InsertEnter",
        keys = {
            { "<C-a>", desc = "Increment word under the cursor" },
            { "<C-x>", desc = "Decrement word under the cursor" },
        }
    },
}
