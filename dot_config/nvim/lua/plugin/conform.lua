local function root_has(bufnr, names)
	local path = vim.api.nvim_buf_get_name(bufnr)
	if path == "" then
		return false
	end

	local dir = vim.fs.dirname(path)
	local found = vim.fs.find(names, {
		path = dir,
		upward = true,
		stop = vim.loop.os_homedir(),
	})

	return #found > 0
end

local function web_formatters(bufnr)
	local has_prettier = root_has(bufnr, {
		"prettier.config.js",
		"prettier.config.mjs",
		"prettier.config.cjs",
		".prettierrc",
		".prettierrc.json",
		".prettierrc.js",
		".prettierrc.cjs",
		".prettierrc.mjs",
		".prettierrc.yaml",
		".prettierrc.yml",
		".prettierrc.toml",
	})

	local has_biome = root_has(bufnr, {
		"biome.json",
		"biome.jsonc",
	})

	if has_prettier then
		return { "prettier" }
	end

	if has_biome then
		return { "biome" }
	end

	return { "biome", "prettier", stop_after_first = true }
end

return {
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },

		opts = {
			formatters_by_ft = {
				typescript = web_formatters,
				typescriptreact = web_formatters,
				javascript = web_formatters,
				javascriptreact = web_formatters,
				json = web_formatters,
				jsonc = web_formatters,
				css = web_formatters,

				yaml = { "prettier", "yamlfmt", stop_after_first = true },
				rust = { "rustfmt", lsp_format = "fallback" },
				python = { "ruff_format" },
				cpp = { "clang_format", lsp_format = "fallback" },
				c = { "clang_format", lsp_format = "fallback" },
				lua = { "stylua" },
			},

			format_on_save = function(bufnr)
				local ft = vim.bo[bufnr].filetype

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

				local name = vim.api.nvim_buf_get_name(bufnr)
				if name == "" then
					return
				end

				local ok, stat = pcall(vim.uv.fs_stat, name)
				if ok and stat and stat.size > 1024 * 1024 then
					return
				end

				return {
					timeout_ms = 1000,
					lsp_format = "fallback",
				}
			end,
		},

		keys = {
			{
				"<leader>cf",
				function()
					require("conform").format({
						async = true,
						lsp_format = "fallback",
					})
				end,
				desc = "Format buffer",
			},
		},
	},
}
