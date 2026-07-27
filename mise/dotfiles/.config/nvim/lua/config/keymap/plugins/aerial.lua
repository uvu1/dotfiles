local utils = require("config.keymap.utils")

-- ]m/[m と ]]/[[ は ftplugin のバッファローカルマップに勝つ必要があるため、
-- ここではなく config.keymap.symbol-nav が LspAttach で張る。
return {
  utils.keymap.lazy("n", "<leader>o", "AerialToggle!", utils.opts("Toggle Aerial")),
}
