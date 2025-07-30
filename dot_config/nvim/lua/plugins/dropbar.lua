return {
    {
        "Bekaboo/dropbar.nvim",
        dependencies = {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "make",
        },
        config = function()
            local dropbar = require("dropbar.api")
            vim.keymap.set("n", "<leader>;", dropbar.pick, { desc = "Pick symbols in winbar" })
            vim.keymap.set("n", "<leader>[;", dropbar.goto_context_start, { desc = "Go to start of current context" })
            vim.keymap.set("n", "<leader>];", dropbar.select_next_context, { desc = "Select next context" })
        end,
        event = "InsertEnter",
    }
}
