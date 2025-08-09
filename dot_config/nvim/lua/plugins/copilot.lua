return {
    {
        "zbirenbaum/copilot.lua",
        opts = {
            suggestion = {
                enabled = true
            }
        },
        event = "InsertEnter",
        cmd = "Copilot",
    },
    {
        "CopilotC-Nvim/CopilotChat.nvim",
        dependencies = {{ "nvim-lua/plenary.nvim", branch = "master" }},
        keys = {
            {
                "<LEADER>ca",
                function ()
                    require("CopilotChat").ask(
                        vim.fn.input("Ask to copilot: "), { selection = require("CopilotChat.select").buffer }
                    )
                end,
                desc = "Ask to copilot",
            },
            {
                "<LEADER>cc",
                function ()
                    require("CopilotChat").toggle()
                end,
                desc = "Toggle copilot chat",
            }
        },
        opts = {
            window = {
                layout = "horizontal",
            },
            selection = function ()
                return require("CopilotChat.select").buffer
            end,
        },
        config = {
            vim.api.nvim_create_autocmd("BufEnter", {
                pattern = "copilot-*",
                callback = function ()
                    vim.opt_local.relativenumber = false
                    vim.opt_local.number = false
                    vim.opt_local.conceallevel = 0
                end
            })
        },
    }
}
