return {
    {
        "rcarriga/nvim-dap-ui",
        dependencies = {
            "mfussenegger/nvim-dap",
            "nvim-neotest/nvim-nio",
            { "theHamsta/nvim-dap-virtual-text", opts = {} },
        },
        config = function ()
            local dap = require("dap")
            dap.adapters.codelldb = {
                type = "executable",
                command = "codelldb",
                preLaunchTask = "gpp-debug",
            }
            dap.configurations.cpp = {
                {
                    name = "Launch",
                    type = "codelldb",
                    request = "launch",
                    program = function()
                        return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
                    end,
                    cwd = "${workspaceFolder}",
                    stopOnEntry = false,
                },
            }
            require("dapui").setup()
        end,
        keys = {
            { "<LEADER>dt", function() require("dapui").toggle() end, desc = "toggle dap-ui" },
            { "<LEADER>dd", function() require("dap").continue() end, desc = "Debug: Start / Continue" },
            { "<LEADER>db", function() require("dap").toggle_breakpoint() end, desc = "Debug: Toggle Breakpoint" },
            {
                "<LEADER>dB",
                function ()
                    require("dap").set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
               end,
            },
            { "<LEADER>de", function() require("dapui").eval() end, desc = "Debug: eval at cursor" },
            { "<LEADER>dE", function() require("dapui").eval(vim.fn.input("[Expression] > ")) end, desc = "Debug: evaluate expression" },
            { "<LEADER>d[", function() require("dap").step_back() end, desc = "Debug: step back" },
            { "<LEADER>d]", function() require("dap").step_over() end, desc = "Debug: step over" },
            { "<LEADER>d{", function() require("dap").step_into() end, desc = "Debug: step into" },
            { "<LEADER>d}", function() require("dap").step_out() end, desc = "Debug: step out" },
            { "<LEADER>dK", function() require("dap.ui.widgets").hover() end, desc = "Debug: Show hover" },
            { "<LEADER>dq", function() require("dap").terminate() end, desc = "Debug: Terminate" },
        }
    }
}
