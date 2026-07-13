local utils = require("config.keymap.utils")

return {
  utils.keymap.lazy("n", "zR", function () require("ufo").openAllFolds() end, utils.opts("Close All Folds (Ufo)")),
  utils.keymap.lazy("n", "zM", function () require("ufo").closeAllFolds() end, utils.opts("Open All Folds (Ufo)")),
  utils.keymap.lazy("n", "zp", function () require("ufo").peekFoldedLinesUnderCursor() end, utils.opts("Peek Folded Lines Under Cursor (Ufo)")),
}
