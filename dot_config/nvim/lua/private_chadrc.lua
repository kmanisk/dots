---@type ChadrcConfig
local M = {}

-- Read canonical system theme state on startup
local system_theme = "gruvchad"
local state_file = vim.fn.expand("~/.local/state/theme/name")
local f_theme = io.open(state_file, "r")
if f_theme then
    local t = f_theme:read("*l")
    f_theme:close()
    if t and t ~= "" then
        system_theme = vim.trim(t)
    end
end
-- UI Configuration
M.ui = {
    theme = system_theme, -- Set the theme for Neovim
    transparency = true, -- Enable transparency
    -- default/vscode/vscode_colored/minimal
    -- default/round/block/arrow separators work only for default statusline theme
    -- round and block will work for minimal theme only
    -- statusline configuration (if you want to use it)
    statusline = {
        enabled = false,
        theme = "vscode", -- default/vscode/vscode_colored/minimal
        separator_style = "default",
        order = { "mode", "file", "git", "%=", "%=", "diagnostics", "lsp", "cursor", "cwd" },
        modules = nil,
    },

    cmp = {
        icons_left = false,
        style = "atom_colored", -- default/flat_light/flat_dark/atom/atom_colored
        abbr_maxwidth = 60,
        format_colors = {
            lsp = true,
            icon = "󱓻",
        },
    },
    telescope = { style = "bordered" }, -- borderless / bordered

    tabufline = {
        enabled = true,
        lazyload = true,
        -- "btns" renders the theme-toggle switch and the close-all X at the
        -- far right of the tab bar. Dropped: both are reachable elsewhere
        -- (<leader>th for the theme, <leader>ct / :bd for buffers).
        order = { "treeOffset", "buffers", "tabs" },
        modules = nil,
        bufwidth = 16,
    },
}

M.base46 = {
    theme = system_theme, -- Change to your preferred base46 theme (e.g., 'tokyonight', 'gruvbox', etc.)
    hl_add = {},
    hl_override = {
        St_Mode = { fg = "white", bg = "one_bg2", bold = true },
        st_mode = { fg = "white", bg = "one_bg2", bold = true },
        StText = { fg = "white" },
        StatusLine = { bg = "black", fg = "black" },
        StatusLineNC = { bg = "black", fg = "black" },
        St_cwd = { fg = "white", bg = "one_bg2", bold = true },
        TelescopePromptTitle = { fg = "white", bg = "one_bg2", bold = true },
        TelescopeResultsTitle = { fg = "white", bg = "one_bg2", bold = true },
        TelescopePreviewTitle = { fg = "white", bg = "one_bg2", bold = true },
    },
    changed_themes = {},
    transparency = true,
    theme_toggle = { "gruvchad", "one_light" },
}

M.nvdash = {
    load_on_startup = false,
    header = {
        "                            ",
        "     ▄▄         ▄ ▄▄▄▄▄▄▄   ",
        "   ▄▀███▄     ▄██ █████▀    ",
        "   ██▄▀███▄   ███           ",
        "   ███  ▀███▄ ███           ",
        "   ███    ▀██ ███           ",
        "   ███      ▀ ███           ",
        "   ▀██ █████▄▀█▀▄██████▄    ",
        "     ▀ ▀▀▀▀▀▀▀ ▀▀▀▀▀▀▀▀▀▀   ",
        "                            ",
        "     Powered By  eovim    ",
        "                            ",
    },
    buttons = {
        { txt = "  Find File", keys = "Spc f f", cmd = "Telescope find_files" },
        { txt = "  Recent Files", keys = "Spc f o", cmd = "Telescope oldfiles" },
    },
}

M.lsp = {
    signature = true,
}

M.cheatsheet = {
    theme = "grid", -- simple/grid
    excluded_groups = { "terminal (t)", "autopairs", "Nvim", "Opens" },
}

M.mason = {
    pkgs = {},
    skip = {},
}

M.colorify = {
    enabled = true,
    mode = "bg", -- fg, bg, virtual
    virt_text = "󱓻 ",
    highlight = { hex = true, lspvars = true },
}

return M
