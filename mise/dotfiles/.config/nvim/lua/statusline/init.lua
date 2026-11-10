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

local tab_groups = {
  active = "StatuslineTabActive",
  inactive = "StatuslineTabInactive",
}

local function setup_highlights()
  local colors = state.colors
  local tab_colors = {
    active = { fg = colors.text, bg = colors.active, bold = true },
    inactive = { fg = colors.inactive_text, bg = colors.inactive },
  }

  vim.api.nvim_set_hl(0, bridge_groups.editor, { fg = colors.inactive_text, bg = colors.inactive })
  vim.api.nvim_set_hl(0, bridge_groups.clear, { fg = colors.inactive, bg = "NONE" })

  for kind, group in pairs(tab_groups) do
    vim.api.nvim_set_hl(0, group, tab_colors[kind])
    vim.api.nvim_set_hl(0, group .. "Cap", { fg = tab_colors[kind].bg, bg = "NONE" })
  end
end

--- lualine の buffers はバッファ間に section/component_separators しか挟めず、
--- pill の separator はコンポーネント全体の両端にしか付かない（全体が 1 本の帯になる）。
--- fmt で各バッファを個別の pill に包み、透明な空白で離す。
local function pill_markup(group, label)
  local cap = "%#" .. group .. "Cap#"

  return cap .. util.caps.left .. "%#" .. group .. "# " .. label .. " " .. cap .. util.caps.right .. " "
end

local function tab_pill(name, buffer)
  -- アイコンと変更マークは fmt の後で apply_mode が pill の外側に付けるので、
  -- ここで取り込んで空にする（Buffer は再描画のたびに作り直される）。
  local label = buffer.icon .. name .. buffer.modified_icon
  buffer.icon, buffer.modified_icon = "", ""

  return pill_markup(tab_groups[buffer.current and "active" or "inactive"], label)
end

--- lualine は fmt の戻り値の文字数で max_length（既定は画面幅の 2/3）を判定するので、
--- 表示されない %#...# の分をバッファ数だけ足す。長い inactive 側で見積もる。
local function tab_max_length()
  local sample = pill_markup(tab_groups.inactive, "")
  local hidden = vim.fn.strchars(sample) - vim.api.nvim_eval_statusline(sample, { use_tabline = true }).width

  return math.floor(2 * vim.o.columns / 3) + hidden * #vim.fn.getbufinfo({ buflisted = 1 })
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

--- VSCode のパンくず。aerial 同梱の lualine コンポーネントをそのまま使う
--- （aerial.nvim/lua/lualine/components/aerial.lua）。
--- explorer・端末・picker では両コンポーネントを cond で落とし、winbar を
--- 空文字にして行そのものを出さない。
function M.winbar()
  local editor = pane.cond("editor")

  return {
    lualine_c = {
      { "filename", path = 1, cond = editor },
      -- aerial 既定の sep_highlight = "NonText" は kawaii ではウィンドウ枠線色
      -- でほぼ見えない。WinBarNC は p.muted かつ
      -- WinBar と同じ背景なので区切りだけ一段暗い正しい見た目になる。
      { "aerial", cond = editor, sep_highlight = "WinBarNC" },
    },
  }
end

--- バッファをタブ風に並べる。各バッファを statusline と同じ色の pill にする（tab_pill）。
function M.tabline()
  return {
    lualine_a = {
      {
        "buffers",
        mode = 0,
        show_filename_only = true,
        symbols = { alternate_file = "" },
        padding = 0,
        fmt = tab_pill,
        max_length = tab_max_length,
      },
    },
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
  setup_highlights()

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
      setup_highlights()
      util.refresh_statusline()
    end,
  })
end

return M
