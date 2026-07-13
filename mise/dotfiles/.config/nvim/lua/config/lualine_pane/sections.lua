local ai = require("config.lualine_pane.ai")
local clock = require("config.lualine_pane.clock")
local components = require("config.lualine_pane.components")
local pane = require("config.lualine_pane.pane")
local state = require("config.lualine_pane.state")
local util = require("config.lualine_pane.util")

local M = {}

local bridge_groups = {
  editor = "LualinePaneEditorBridge",
  clear = "LualinePaneClearBridge",
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
  local function ai_status_cond(check)
    return function()
      return pane.kind() == "ai" and check()
    end
  end
  local right_sections = {
    util.pill(components.editor_position, {
      cond = pane.cond("editor"),
      color = { fg = colors.inactive_text, bg = colors.inactive },
    }),
    util.pill(components.editor_indent, {
      cond = pane.cond("editor"),
      color = { fg = colors.inactive_text, bg = colors.inactive },
    }),
    util.pill(components.editor_encoding, {
      cond = pane.cond("editor"),
      color = { fg = colors.inactive_text, bg = colors.inactive },
    }),
    util.pill(components.editor_line_ending, {
      cond = pane.cond("editor"),
      color = { fg = colors.inactive_text, bg = colors.inactive },
    }),
    util.pill(components.editor_time, {
      cond = pane.cond("editor"),
      color = { fg = colors.text, bg = colors.active, gui = "bold" },
    }),
    util.pill(components.ai_context_usage, {
      cond = ai_status_cond(components.ai_has_context_usage),
      color = components.ai_context_usage_color,
    }),
    util.pill(components.ai_thinking_level, {
      cond = ai_status_cond(components.ai_has_thinking_level),
      color = { fg = colors.text, bg = colors.active, gui = "bold" },
    }),
    util.pill(components.ai_model, {
      cond = ai_status_cond(components.ai_has_model),
      color = { fg = colors.text, bg = colors.title, gui = "bold" },
    }),
  }

  return {
    lualine_a = {
      util.pill(components.focused_mode, {
        cond = pane.focused_cond("editor"),
        color = components.focused_mode_color,
      }),
      util.pill(components.explorer_files, {
        cond = pane.cond("explorer"),
        color = { fg = colors.text, bg = colors.active, gui = "bold" },
      }),
      util.pill(components.editor_diagnostics, {
        cond = pane.cond("editor"),
        color = { fg = colors.text, bg = colors.title, gui = "bold" },
      }),
      util.pill(components.editor_os, {
        cond = pane.cond("editor"),
        color = { fg = colors.inactive_text, bg = colors.inactive },
      }),
      util.pill(components.editor_language, {
        cond = pane.cond("editor"),
        color = { fg = colors.inactive_text, bg = colors.inactive },
      }),
      util.pill(components.ai_elapsed, {
        cond = pane.cond("ai"),
        color = components.ai_elapsed_color,
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

  ai.setup()
  clock.setup()

  local group = vim.api.nvim_create_augroup("LualinePaneRefresh", { clear = true })

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
