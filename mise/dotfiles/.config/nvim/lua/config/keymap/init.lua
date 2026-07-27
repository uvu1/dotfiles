local modules = {
	"config.keymap.base",
	"config.keymap.utils",
	"config.keymap.competitive",
	"config.keymap.symbol-nav",
}

for _, module in ipairs(modules) do
	require(module)
end
