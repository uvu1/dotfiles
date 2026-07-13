return {
	{
		"mfussenegger/nvim-lint",
		event = { "BufReadPost", "BufWritePost", "InsertLeave" },

		config = function()
			local lint = require("lint")

			lint.linters_by_ft = {
				typescript = { "biomejs" },
				typescriptreact = { "biomejs" },

				javascript = { "biomejs" },
				javascriptreact = { "biomejs" },

				json = { "biomejs" },
				jsonc = { "biomejs" },
				css = { "biomejs" },

				yaml = { "yamllint" },

				python = { "ruff" },
			}

			local group = vim.api.nvim_create_augroup("uvu-lint", { clear = true })

			vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
				group = group,
				callback = function(args)
					local ft = vim.bo[args.buf].filetype

					if
						vim.tbl_contains({
							"codecompanion",
							"pane-tabs-ai",
							"snacks_terminal",
							"terminal",
							"prompt",
						}, ft)
					then
						return
					end

					local name = vim.api.nvim_buf_get_name(args.buf)
					if name == "" then
						return
					end

					require("lint").try_lint()
				end,
			})
		end,
	},
}
