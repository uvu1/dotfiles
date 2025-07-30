return {
    {
        "nvimtools/none-ls.nvim",
        dependencies = { "davidmh/cspell.nvim" },
        config = function ()
            local cspell = require("cspell")
            local sources = {
                cspell.diagnostics.with({
                    diagnostics_postprocess = function (diag)
                        diag.severity = vim.diagnostic.severity.WARN
                    end,
                }),
                cspell.code_actions
            }
            require("null-ls").setup({
                sources = sources
            })
        end,
        event = "VeryLazy"
    }
}
