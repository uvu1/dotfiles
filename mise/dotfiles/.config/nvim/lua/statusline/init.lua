local clock = require("statusline.clock")
local editor = require("statusline.editor")
local pane = require("statusline.pane")
local state = require("statusline.state")
local util = require("statusline.util")

local M = {}

local bridge_groups = {
  editor = "StatuslineEditorBridge",
  clear = "StatuslineClearBridge",
}

local function bridge_component()
  local group = pane.kind() == "editor" and bridge_groups.editor or bridge_groups.clear

  return "%#" .. group .. "#%=%#" .. group .. "#"
end

local function bridge_highlight()
  return {
    bridge_component,
    separator = { left = "", right = "" },
    padding = { left = 0, right = 0 },
  }
end

local function setup_bridge_highlights()
  local colors = state.colors

  vim.api.nvim_set_hl(0, bridge_groups.editor, { fg = colors.inactive_text, bg = colors.inactive })
  vim.api.nvim_set_hl(0, bridge_groups.clear, { fg = colors.inactive, bg = "NONE" })
end

function M.sections()
  local colors = state.colors
  local right_sections = {
    util.pill(editor.editor_position, {
      cond = pane.cond("editor"),
      color = { fg = colors.inactive_text, bg = colors.inactive },
    }),
    util.pill(editor.editor_indent, {
      cond = pane.cond("editor"),
      color = { fg = colors.inactive_text, bg = colors.inactive },
    }),
    util.pill(editor.editor_encoding, {
      cond = pane.cond("editor"),
      color = { fg = colors.inactive_text, bg = colors.inactive },
    }),
    util.pill(editor.editor_line_ending, {
      cond = pane.cond("editor"),
      color = { fg = colors.inactive_text, bg = colors.inactive },
    }),
    util.pill(editor.editor_time, {
      cond = pane.cond("editor"),
      color = { fg = colors.text, bg = colors.active, gui = "bold" },
    }),
  }

  return {
    lualine_a = {
      util.pill(editor.focused_mode, {
        cond = pane.focused_cond("editor"),
        color = editor.focused_mode_color,
      }),
      util.pill(editor.explorer_files, {
        cond = pane.cond("explorer"),
        color = { fg = colors.text, bg = colors.active, gui = "bold" },
      }),
      util.pill(editor.editor_diagnostics, {
        cond = pane.cond("editor"),
        color = { fg = colors.text, bg = colors.title, gui = "bold" },
      }),
      util.pill(editor.editor_os, {
        cond = pane.cond("editor"),
        color = { fg = colors.inactive_text, bg = colors.inactive },
      }),
      util.pill(editor.editor_language, {
        cond = pane.cond("editor"),
        color = { fg = colors.inactive_text, bg = colors.inactive },
      }),
    },
    lualine_b = {},
    lualine_c = vim.list_extend({ bridge_highlight() }, right_sections),
    lualine_x = {},
    lualine_y = {},
    lualine_z = {},
  }
end

function M.theme()
  local function section()
    return { fg = state.colors.inactive, bg = state.colors.transparent }
  end

  return {
    normal = { a = section(), b = section(), c = section(), x = section(), y = section(), z = section() },
    insert = { a = section(), b = section(), c = section(), x = section(), y = section(), z = section() },
    visual = { a = section(), b = section(), c = section(), x = section(), y = section(), z = section() },
    replace = { a = section(), b = section(), c = section(), x = section(), y = section(), z = section() },
    command = { a = section(), b = section(), c = section(), x = section(), y = section(), z = section() },
    inactive = { a = section(), b = section(), c = section(), x = section(), y = section(), z = section() },
  }
end

function M.setup()
  setup_bridge_highlights()

  clock.setup()

  local group = vim.api.nvim_create_augroup("StatuslineRefresh", { clear = true })

  vim.api.nvim_create_autocmd({
    "BufWinEnter",
    "DiagnosticChanged",
    "WinClosed",
    "WinNew",
    "WinResized",
  }, {
    group = group,
    callback = util.refresh_statusline,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      setup_bridge_highlights()
      util.refresh_statusline()
    end,
  })
end

return M
