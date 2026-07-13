local overseer = require("overseer")

local function has_justfile()
	return vim.fs.find({ "justfile", "Justfile", ".justfile" }, {
		upward = true,
		path = vim.fn.getcwd(),
	})[1] ~= nil
end

local function just_recipes()
	local output = vim.fn.systemlist({ "just", "--summary" })

	if vim.v.shell_error ~= 0 then
		return {}
	end

	local recipes = {}
	for _, line in ipairs(output) do
		for recipe in line:gmatch("%S+") do
			table.insert(recipes, recipe)
		end
	end

	table.sort(recipes)
	return recipes
end

return {
	generator = function(_, cb)
		if not has_justfile() then
			cb({})
			return
		end

		local tasks = {}

		for _, recipe in ipairs(just_recipes()) do
			table.insert(tasks, {
				name = "just " .. recipe,
				builder = function()
					return {
						cmd = "just",
						args = { recipe },
						components = {
							"default",
							"on_output_quickfix",
							"on_result_diagnostics",
						},
					}
				end,
			})
		end

		cb(tasks)
	end,
}
