return {
    {
        "mason-org/mason.nvim",
        config = true,
        build = ":MasonUpdate",
    },
    {
        "mason-org/mason-lspconfig.nvim",
        dependencies = {
            {
                "neovim/nvim-lspconfig",
                config = function (_, opts)
                    vim.diagnostic.config({
                        virtual_text = true,
                    })
                end
            },
            { "mason-org/mason.nvim" },
        },
        opts = {},
        event = "VeryLazy",
    },
    {
        "saghen/blink.cmp",
        dependencies = {
            "rafamadriz/friendly-snippets",
            "L3MON4D3/LuaSnip",
            "fang2hou/blink-copilot",
            "xzbdmw/colorful-menu.nvim",
        },
        event = "VeryLazy",
        version = "1.*",
        ---@module "blink.cmp"
        ---@type blink.cmp.Config
        opts = {
            keymap = { preset = "super-tab" },
            appearance = {
                nerd_font_variant = "mono",
            },
            completion = { 
                documentation = { auto_show = false },
                menu = {
                    draw = {
                        columns = { { "kind_icon" }, { "label", gap = 1 } },
                        components = {
                            label = {
                                text = function (ctx)
                                    return require("colorful-menu").blink_components_text(ctx)
                                end,
                                highlight = function (ctx)
                                    return require("colorful-menu").blink_components_highlight(ctx)
                                end
                            }
                        }
                    }
                }
            },
            sources = {
                default = {"lazydev", "lsp", "path", "snippets", "buffer", "copilot"},
                providers = {
                    lazydev = {
                        name = "LazyDev",
                        module = "lazydev.integrations.blink",
                        score_offset = 100,
                    },
                    copilot = {
                        name = "copilot",
                        module = "blink-copilot",
                        score_offset = 100, 
                        async = true,
                    }
                },
            },
            snippets = { preset = "luasnip" },
        },
        opts_extend = { "sources.default" },
    },
    {
        "folke/lazydev.nvim",
        ft = "lua", -- only load on lua files
        opts = {
            library = {
                { path = "${3rd}/luv/library", words = { "vim%.uv" } },
            },
        },
    },
}
