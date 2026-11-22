return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-mini/mini.icons" },
    config = function()
      local editor = require("statusline.editor")
      local pane = require("statusline.pane")
      local runtime = require("statusline.runtime")
      local is_editor = pane.cond("editor")
      runtime.setup()
      vim.opt.laststatus = 2

      local sections = {
        lualine_a = {
          { "mode", cond = pane.focused_cond("editor") },
          { editor.explorer_files, cond = pane.cond("explorer") },
        },
        lualine_b = {
          { editor.diagnostics, cond = is_editor },
          { runtime.os_info, cond = is_editor },
          { "filetype", fmt = editor.language, cond = is_editor },
        },
        lualine_c = {},
        lualine_x = {
          { editor.position, cond = is_editor },
          { editor.indent, cond = is_editor },
          { "encoding", fmt = editor.encoding, icon = "󰉿", cond = is_editor },
          { "fileformat", symbols = { unix = "LF", dos = "CRLF", mac = "CR" }, icon = "󰌑", cond = is_editor },
        },
        lualine_y = {},
        lualine_z = { { "datetime", style = "%H:%M", icon = "󰥔", cond = is_editor } },
      }
      require("lualine").setup({
        options = {
          -- 描画・色分け・時計・バッファの幅計算は組込に任せる。
          theme = "auto",
          globalstatus = false,
          refresh = {
            events = {
              "WinEnter",
              "BufEnter",
              "BufWinEnter",
              "BufWritePost",
              "SessionLoadPost",
              "FileChangedShellPost",
              "VimResized",
              "FileType",
              "CursorMoved",
              "CursorMovedI",
              "ModeChanged",
              "DiagnosticChanged",
              "WinClosed",
              "WinNew",
              "WinResized",
            },
          },
        },
        sections = sections,
        inactive_sections = vim.deepcopy(sections),
        tabline = {
          lualine_a = { { "buffers", mode = 0, show_filename_only = true, symbols = { alternate_file = "" } } },
        },
        winbar = { lualine_c = { { "filename", path = 1, cond = is_editor } } },
        inactive_winbar = {},
      })
    end,
  },
}
