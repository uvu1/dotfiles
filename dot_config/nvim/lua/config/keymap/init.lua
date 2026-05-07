local modules = {
  "config.keymap.base",
  "config.keymap.snacks",
  "config.keymap.ai",
  "config.keymap.trouble",
}

for _, module in ipairs(modules) do
  require(module)
end
