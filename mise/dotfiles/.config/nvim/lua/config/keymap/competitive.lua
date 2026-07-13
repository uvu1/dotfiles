local utils = require("config.keymap.utils")

local function save_current_buffer()
	if vim.bo.buftype ~= "" or vim.api.nvim_buf_get_name(0) == "" or not vim.bo.modifiable then
		return true
	end

	local ok, err = pcall(vim.cmd, "silent update")
	if not ok then
		vim.notify("AtCoder: failed to write current buffer: " .. tostring(err), vim.log.levels.ERROR)
		return false
	end

	return true
end

local function current_file_dir()
	local name = vim.api.nvim_buf_get_name(0)
	if name == "" then
		return nil
	end

	return vim.fn.fnamemodify(name, ":p:h")
end

local function term(cmd, opts)
	opts = opts or {}
	local cwd = opts.cwd
	if type(cwd) == "function" then
		cwd = cwd()
	end

	if not save_current_buffer() then
		return
	end

	vim.cmd("botright 15new")
	vim.bo.buflisted = false

	local job_opts = { term = true }
	if cwd and cwd ~= "" then
		job_opts.cwd = cwd
	end

	local job_id = vim.fn.jobstart({ vim.o.shell, vim.o.shellcmdflag, cmd }, job_opts)
	if job_id <= 0 then
		vim.notify("AtCoder: failed to start terminal: " .. cmd, vim.log.levels.ERROR)
		vim.cmd("bdelete!")
		return
	end

	vim.cmd("startinsert")
end

local function input_term(prompt, cmd_builder)
	vim.ui.input({ prompt = prompt }, function(input)
		if not input or input == "" then
			return
		end

		term(cmd_builder(input))
	end)
end

-- AtCoder / Competitive Programming
utils.keymap.vim("n", "<leader>ct", function()
	term("mise run test", { cwd = current_file_dir })
end, utils.opts("AtCoder: sample test"))

utils.keymap.vim("n", "<leader>cd", function()
	term("mise run test-debug")
end, utils.opts("AtCoder: sample test debug"))

utils.keymap.vim("n", "<leader>cr", function()
	term("mise run run")
end, utils.opts("AtCoder: run with stdin"))

utils.keymap.vim("n", "<leader>cu", function()
	term("mise run submit", { cwd = current_file_dir })
end, utils.opts("AtCoder: submit"))

utils.keymap.vim("n", "<leader>cb", function()
	term("mise run build-image")
end, utils.opts("AtCoder: build Podman image"))

utils.keymap.vim("n", "<leader>cn", function()
	input_term("contest id: ", function(contest)
		return "mise run new " .. vim.fn.shellescape(contest)
	end)
end, utils.opts("AtCoder: new contest"))

utils.keymap.vim("n", "<leader>co", function()
	term("mise exec --command 'oj login --check https://atcoder.jp/ && acc session'")
end, utils.opts("AtCoder: check login"))
