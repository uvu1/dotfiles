local modules = {
	"config.keymap.base",
	"config.keymap.utils",
	"config.keymap.competitive",
}

for _, module in ipairs(modules) do
	require(module)
end
