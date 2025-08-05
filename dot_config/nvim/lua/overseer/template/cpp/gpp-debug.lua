--@type overseer.TemplateDefinition
return {
    name = "gpp-debug",
    builder = function ()
        local file = vim.fn.expand("%:p")
        local outfile = vim.fn.expand("%:p:r") .. ".out"
        --@type overseer.TaskDefinition
        return {
            cmd = {"g++"},
            args = {"-g", "-O0", file, "-o", outfile },
            components = {
                { "on_output_quickfix", open_on_exit = "failure" },
                "default",
            },
        }
    end,
    priority = 1000,
    condition = {
        filetype = {"cpp"}
    }
}
