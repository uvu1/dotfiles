return {
    {
        "kylechui/nvim-surround",
        version = "^3.0.0",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("nvim-surround").setup({})
        end
    }
}
