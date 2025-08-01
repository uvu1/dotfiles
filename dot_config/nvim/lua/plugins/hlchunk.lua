return {
    {
        "shellRaining/hlchunk.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("hlchunk").setup({
                chunk = {
                    enable = true,
                    use_treesitter = true,
                },
                indent = {
                    enable = true,
                },
                line_num = {
                    enable = true,
                },
            })
        end
    }
}
