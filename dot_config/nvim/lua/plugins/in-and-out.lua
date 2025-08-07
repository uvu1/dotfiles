return {
    {
        "ysmb-wtsg/in-and-out.nvim",
        keys = {
            {
                "<C-j>", -- <C-CR> will not work in some terminals T_T
                function ()
                    require("in-and-out").in_and_out()
                end,
                mode = "i",
            },
        },
        opts = {},
    },
}
