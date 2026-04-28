local wezterm = require("wezterm")

local module = {}

local EDGE_BG = "#0b0e14"

local INDEX_LEFT_PAD = "  "
local INDEX_RIGHT_PAD = " "
local TITLE_LEFT_PAD = ""
local TITLE_RIGHT_PAD = "  "
local TAB_GAP = " "

local ACTIVE_BG = "#7aa2f7"
local ACTIVE_FG = "#0b0e14"

local INACTIVE_BG = "#151922"
local INACTIVE_FG = "#a9b1d6"

local HOVER_BG = "#24283b"
local HOVER_FG = "#c0caf5"

local function basename(s)
    return string.gsub(s, "(.*[/\\])(.*)", "%2")
end

local function is_windows()
    return wezterm.target_triple:find("windows") ~= nil
end

local function is_macos()
    return wezterm.target_triple:find("darwin") ~= nil
end

local function normalize_process_name(name)
    if not name or name == "" then
        return ""
    end

    name = basename(name)
    name = name:lower()
    name = name:gsub("%.exe$", "")

    return name
end

local function foreground_process_info(pane)
    local ok, info = pcall(function()
        return pane:get_foreground_process_info()
    end)

    if ok then
        return info
    end

    return nil
end

local ssh_options_with_arg = {
    ["-b"] = true,
    ["-c"] = true,
    ["-D"] = true,
    ["-E"] = true,
    ["-e"] = true,
    ["-F"] = true,
    ["-I"] = true,
    ["-i"] = true,
    ["-J"] = true,
    ["-L"] = true,
    ["-l"] = true,
    ["-m"] = true,
    ["-O"] = true,
    ["-o"] = true,
    ["-p"] = true,
    ["-Q"] = true,
    ["-R"] = true,
    ["-S"] = true,
    ["-W"] = true,
    ["-w"] = true,
}

local function ssh_host_from_argv(argv)
    if not argv or #argv == 0 then
        return nil
    end

    local i = 2

    while i <= #argv do
        local arg = argv[i]

        if arg == "--" then
            local host = argv[i + 1]
            if host then
                return host:gsub("^.-@", "")
            end
            return nil
        end

        if ssh_options_with_arg[arg] then
            i = i + 2
        elseif arg:match("^%-[bcDEeFIiJLlmOoPQRSWw].+") then
            i = i + 1
        elseif arg:sub(1, 1) == "-" then
            i = i + 1
        else
            local host = arg
            host = host:gsub("^.-@", "")
            host = host:gsub("^%[", ""):gsub("%]$", "")
            return host
        end
    end

    return nil
end

local function cwd_name(pane)
    local cwd = pane.current_working_dir and tostring(pane.current_working_dir) or ""

    if cwd == "" then
        return ""
    end

    cwd = cwd:gsub("^file://", "")
    cwd = cwd:gsub("%%20", " ")

    return basename(cwd)
end

local function tab_title(tab)
    if tab.tab_title and #tab.tab_title > 0 then
        return tab.tab_title
    end

    local pane = tab.active_pane
    local proc = normalize_process_name(pane.foreground_process_name)
    local info = foreground_process_info(pane)
    local argv = info and info.argv or nil
    local cwd = cwd_name(pane)

    if proc == "ssh" then
        local host = ssh_host_from_argv(argv)

        if host then
            return "󰣀 ssh " .. host
        end

        return "󰣀 ssh"
    end

    if is_windows() then
        if proc == "pwsh" or proc == "powershell" then
            if cwd ~= "" then
                return " pwsh " .. cwd
            end

            return " pwsh"
        end

        if proc == "wsl" or proc == "wslhost" then
            if cwd ~= "" then
                return "󰌽 wsl " .. cwd
            end

            return "󰌽 wsl"
        end
    end

    if is_macos() then
        if proc == "zsh" then
            if cwd ~= "" then
                return " zsh " .. cwd
            end

            return " zsh"
        end
    end

    if proc ~= "" then
        if cwd ~= "" then
            return " " .. proc .. " " .. cwd
        end

        return " " .. proc
    end

    return pane.title
end

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
    local title = tab_title(tab)
    local index = tostring(tab.tab_index + 1)

    if #title > max_width - 8 then
        title = wezterm.truncate_right(title, max_width - 9) .. "…"
    end

    local bg
    local fg

    if tab.is_active then
        bg = ACTIVE_BG
        fg = ACTIVE_FG
    elseif hover then
        bg = HOVER_BG
        fg = HOVER_FG
    else
        bg = INACTIVE_BG
        fg = INACTIVE_FG
    end

    return {
        { Background = { Color = EDGE_BG } },
        { Foreground = { Color = bg } },
        { Text = "" },

        { Background = { Color = bg } },
        { Foreground = { Color = fg } },
        { Text = INDEX_LEFT_PAD .. index .. INDEX_RIGHT_PAD },

        { Background = { Color = bg } },
        { Foreground = { Color = fg } },
        { Text = TITLE_LEFT_PAD .. title .. TITLE_RIGHT_PAD },

        { Background = { Color = EDGE_BG } },
        { Foreground = { Color = bg } },
        { Text = "" .. TAB_GAP },
    }
end)

function module.apply(config)
    config.use_fancy_tab_bar = false
    config.tab_bar_at_bottom = false
    config.hide_tab_bar_if_only_one_tab = false
    config.show_new_tab_button_in_tab_bar = false
    config.show_close_tab_button_in_tabs = false
    config.tab_max_width = 32

    config.colors = config.colors or {}

    config.window_frame = {
        inactive_titlebar_bg = "none",
        active_titlebar_bg = "none",
    }
    config.window_background_gradient = {
        colors = { "#000000" },
    }

    config.colors.tab_bar = {
        background = EDGE_BG,
        inactive_tab_edge = "none",
        active_tab = {
            bg_color = ACTIVE_BG,
            fg_color = ACTIVE_FG,
            intensity = "Bold",
        },
        inactive_tab = {
            bg_color = INACTIVE_BG,
            fg_color = INACTIVE_FG,
        },
        inactive_tab_hover = {
            bg_color = HOVER_BG,
            fg_color = HOVER_FG,
            italic = false,
        },
    }
end

return module