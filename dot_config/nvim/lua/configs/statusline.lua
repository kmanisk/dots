-- Minimal, dependency-free statusline.
--
-- Why this exists: base46 forces the StatusLine background to NONE when
-- transparency is enabled, and this NvChad build ships no statusline
-- implementation, so there was literally nothing to render. This module draws
-- a compact bar with a solid background taken from the active theme, so it
-- stays readable over a transparent editor.
--
-- Position in the UI: a single global bar at the bottom (laststatus = 3),
-- similar to the status bar at the bottom of Zed.

local M = {}

local fallback = {
    black = "#14161a",
    black2 = "#242728",
    one_bg = "#282b2c",
    lightbg = "#2d3031",
    grey = "#484b4c",
    grey_fg = "#575a5b",
    light_grey = "#606364",
    white = "#c7b89d",
    red = "#ec6b64",
    green = "#89b482",
    yellow = "#d6b676",
    blue = "#6d8dad",
    nord_blue = "#6f8faf",
    purple = "#9385b4",
    orange = "#e78a4e",
    statusline_bg = "#222526",
}

--- Theme colours from base46, with a static fallback so a theme swap can never
--- break the bar.
local function colors()
    local ok, base46 = pcall(require, "base46")
    if not ok then
        return fallback
    end
    local ok_tb, tb = pcall(base46.get_theme_tb, "base_30")
    if not ok_tb or type(tb) ~= "table" then
        return fallback
    end
    local out = {}
    for key, default in pairs(fallback) do
        local value = tb[key]
        out[key] = (type(value) == "string" and value ~= "") and value or default
    end
    return out
end

function M.highlights()
    local c = colors()
    local set = vim.api.nvim_set_hl
    local bar = c.statusline_bg

    -- Bar background, used for the fill between the left and right segments.
    set(0, "SlBar", { fg = c.white, bg = bar })

    -- Mode chips: solid backgrounds so the current mode is obvious at a glance.
    set(0, "SlNormal", { fg = c.black, bg = c.nord_blue, bold = true })
    set(0, "SlInsert", { fg = c.black, bg = c.green, bold = true })
    set(0, "SlVisual", { fg = c.black, bg = c.purple, bold = true })
    set(0, "SlReplace", { fg = c.white, bg = c.red, bold = true })
    set(0, "SlCommand", { fg = c.black, bg = c.yellow, bold = true })

    -- Content segments.
    set(0, "SlFile", { fg = c.white, bg = c.lightbg, bold = true })
    set(0, "SlModified", { fg = c.red, bg = c.lightbg, bold = true })
    set(0, "SlGit", { fg = c.green, bg = bar })
    set(0, "SlDiagError", { fg = c.red, bg = bar, bold = true })
    set(0, "SlDiagWarn", { fg = c.yellow, bg = bar, bold = true })
    set(0, "SlDiagInfo", { fg = c.blue, bg = bar })
    set(0, "SlLsp", { fg = c.nord_blue, bg = bar })
    set(0, "SlFiletype", { fg = c.light_grey, bg = bar })
    set(0, "SlCursor", { fg = c.white, bg = bar, bold = true })
    set(0, "SlCwd", { fg = c.grey_fg, bg = bar })

    -- Border colour for floating terminals, so a terminal float never looks
    -- like an ordinary float.
    set(0, "SlTermBorder", { fg = c.orange, bg = c.black2 })
end

local function mode_chip(mode)
    local map = {
        n = { "NORMAL", "SlNormal" },
        i = { "INSERT", "SlInsert" },
        v = { "VISUAL", "SlVisual" },
        V = { "V-LINE", "SlVisual" },
        ["\22"] = { "V-BLOCK", "SlVisual" },
        s = { "SELECT", "SlVisual" },
        S = { "S-LINE", "SlVisual" },
        R = { "REPLACE", "SlReplace" },
        r = { "PENDING", "SlReplace" },
        c = { "COMMAND", "SlCommand" },
        ["!"] = { "SHELL", "SlCommand" },
    }
    local entry = map[mode] or map[mode:sub(1, 1)] or { mode:upper(), "SlNormal" }
    return entry[1], entry[2]
end

--- Percent signs are statusline field markers, so literal ones must be doubled.
local function esc(text)
    return (text:gsub("%%", "%%%%"))
end

local function diagnostic_counts()
    local ok, counts = pcall(vim.diagnostic.count, 0)
    if ok and type(counts) == "table" then
        return counts[vim.diagnostic.severity.ERROR] or 0,
            counts[vim.diagnostic.severity.WARN] or 0,
            counts[vim.diagnostic.severity.INFO] or 0,
            counts[vim.diagnostic.severity.HINT] or 0
    end
    return 0, 0, 0, 0
end

local function lsp_count()
    local ok, clients = pcall(vim.lsp.get_clients, { bufnr = 0 })
    return ok and #clients or 0
end

function M.render()
    -- Terminal windows never render statusline content. The bar itself is
    -- hidden globally by default (laststatus = 0); this keeps terminal windows
    -- blank even when the bar is switched on with <leader>us.
    if vim.bo.buftype == "terminal" then
        return ""
    end

    local mode = vim.api.nvim_get_mode().mode
    local chip, chip_hl = mode_chip(mode)
    local parts = { "%#" .. chip_hl .. "# " .. chip .. " " }

    local name = vim.fn.expand("%:t")
    if name == "" then
        name = vim.bo.buftype ~= "" and vim.bo.buftype or "untitled"
    end
    parts[#parts + 1] = "%#SlFile# " .. esc(name) .. " "
    if vim.bo.modified then
        parts[#parts + 1] = "%#SlModified# * "
    end

    local gs = vim.b.gitsigns_status_dict
    if type(gs) == "table" and type(gs.head) == "string" and gs.head ~= "" then
        parts[#parts + 1] = "%#SlGit#  " .. esc(gs.head) .. " "
    end

    parts[#parts + 1] = "%#SlBar#%="

    local err, warn, info, hint = diagnostic_counts()
    if err > 0 then
        parts[#parts + 1] = "%#SlDiagError# E" .. err .. " "
    end
    if warn > 0 then
        parts[#parts + 1] = "%#SlDiagWarn# W" .. warn .. " "
    end
    if info + hint > 0 then
        parts[#parts + 1] = "%#SlDiagInfo# I" .. (info + hint) .. " "
    end

    local clients = lsp_count()
    if clients > 0 then
        parts[#parts + 1] = "%#SlLsp# LSP:" .. clients .. " "
    end

    local ft = vim.bo.filetype
    if ft ~= "" then
        parts[#parts + 1] = "%#SlFiletype# " .. esc(ft) .. " "
    end

    parts[#parts + 1] = "%#SlCursor# " .. vim.fn.line(".") .. ":" .. vim.fn.col(".") .. " "
    parts[#parts + 1] = "%#SlCwd# " .. esc(vim.fn.fnamemodify(vim.fn.getcwd(), ":t")) .. " "
    return table.concat(parts)
end

--- Show or hide the bottom bar. Hiding leaves the tabline untouched, because
--- the tabline is governed by 'showtabline' and not by 'laststatus'.
function M.toggle()
    if vim.o.laststatus == 0 then
        M.highlights()
        vim.o.laststatus = 3
        vim.notify("Statusline on", vim.log.levels.INFO, { title = "UI" })
    else
        vim.o.laststatus = 0
        vim.notify("Statusline off", vim.log.levels.INFO, { title = "UI" })
    end
end

function M.setup()
    M.highlights()
    local group = vim.api.nvim_create_augroup("SlThemeRefresh", { clear = true })

    -- base46 does not emit ColorScheme; it emits User NvThemeReload after
    -- load_all_highlights(), which is what Huefy and the system theme sync use.
    vim.api.nvim_create_autocmd("User", {
        group = group,
        pattern = "NvThemeReload",
        callback = M.highlights,
        desc = "Re-theme the statusline after a theme change",
    })
    vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        pattern = "*",
        callback = M.highlights,
        desc = "Re-theme the statusline after a colorscheme change",
    })
end

return M
