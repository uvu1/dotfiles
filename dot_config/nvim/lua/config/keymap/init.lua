local modules = {
	"config.keymap.base",
	"config.keymap.utils",
}

for _, module in ipairs(modules) do
	require(module)
end
