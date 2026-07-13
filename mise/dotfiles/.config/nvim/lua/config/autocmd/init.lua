local modules = {
  "config.autocmd.vimenter",
}

for _, module in ipairs(modules) do
  require(module)
end
