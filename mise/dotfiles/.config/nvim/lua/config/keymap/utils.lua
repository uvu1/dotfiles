local function normalize_rhs(rhs)
	if type(rhs) == "string" then
		if rhs:sub(1, 1) == "<" and rhs:sub(-1) == ">" then
			return rhs
		end

		return "<cmd>" .. rhs .. "<cr>"
	end

	return rhs
end

local lazyset = function(mode, lhs, rhs, opts)
	opts = opts or {}
	local spec = {
		lhs,
		normalize_rhs(rhs),
		mode = mode,
	}

	for k, v in pairs(opts) do
		spec[k] = v
	end

	return spec
end

--- return options
--- @param desc string Description of keybind
local opts = function(desc)
	return {
		noremap = true,
		silent = true,
		desc = desc,
	}
end

return {
	opts = opts,
	keymap = {
		lazy = lazyset,
		vim = vim.keymap.set,
	},
}
