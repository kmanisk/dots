-- Start page (alpha-nvim).
--
-- Two entry points:
--   1. Launching nvim without arguments shows the start page.
--   2. Closing the last buffer returns to it instead of leaving an empty
--      "No Name" buffer behind.
--
-- Colours come from the base46 integration (AlphaHeader / AlphaButtons), so the
-- page follows the active theme without any hardcoded hex values.

local M = {}

local function dashboard()
    local alpha = require("alpha")
    local theme = require("alpha.themes.dashboard")

    theme.section.header.val = {
        [[ ███╗   ██╗██╗   ██╗██╗███╗   ███╗ ]],
        [[ ████╗  ██║██║   ██║██║████╗ ████║ ]],
        [[ ██╔██╗ ██║██║   ██║██║██╔████╔██║ ]],
        [[ ██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║ ]],
        [[ ██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║ ]],
        [[ ╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝ ]],
    }
    theme.section.header.opts.hl = "AlphaHeader"

    local config_path = vim.fn.stdpath("config") .. "/lua/chadrc.lua"

    theme.section.buttons.val = {
        theme.button("f", "Find file", ":Telescope find_files<cr>"),
        theme.button("r", "Recent files", ":Telescope oldfiles<cr>"),
        theme.button("g", "Search text", ":Telescope live_grep<cr>"),
        theme.button("n", "New file", ":enew<cr>"),
        theme.button("c", "Edit config", ":edit " .. vim.fn.fnameescape(config_path) .. "<cr>"),
        theme.button("q", "Quit", ":qa<cr>"),
    }
    theme.section.buttons.opts.hl = "AlphaButtons"

    theme.section.footer.val = {
        vim.fn.fnamemodify(vim.fn.getcwd(), ":~"),
        "Neovim " .. vim.version().major .. "." .. vim.version().minor .. "." .. vim.version().patch,
    }
    theme.section.footer.opts.hl = "AlphaHeader"

    -- Do not let alpha install its own VimEnter autostart. The session layer
    -- decides: a restored session must win, the start page is only a fallback.
    theme.config.opts.autostart = false

    alpha.setup(theme.config)
end

--- True when every listed buffer is an empty, unnamed scratch buffer, which is
--- all that is left after the last real file is closed.
local function only_scratch_buffers()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
            if vim.api.nvim_buf_get_name(buf) ~= "" then
                return false
            end
            if vim.bo[buf].buftype ~= "" or vim.bo[buf].filetype ~= "" then
                return false
            end
            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
            if #lines > 1 or (lines[1] ~= nil and lines[1]:match("%S") ~= nil) then
                return false
            end
        end
    end
    return true
end

local busy = false

-- Sidebar windows must never host the start page. The BufDelete hook can fire
-- while the tree has focus, and alpha.start() paints into the current window,
-- which would replace the tree buffer with the dashboard.
local SIDEBAR_FILETYPES = {
    NvimTree = true,
    oil = true,
    ["neo-tree"] = true,
}

local function is_sidebar(win)
    local buf = vim.api.nvim_win_get_buf(win)
    return SIDEBAR_FILETYPES[vim.bo[buf].filetype] == true
end

--- Every window currently showing an alpha buffer.
local function alpha_windows()
    local wins = {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "alpha" then
            wins[#wins + 1] = win
        end
    end
    return wins
end

--- A normal editing window: the current one, any other non-sidebar window, or
--- a fresh split when only sidebars are open.
local function editor_window()
    local current = vim.api.nvim_get_current_win()
    if not is_sidebar(current) and vim.api.nvim_win_get_config(current).relative == "" then
        return current
    end
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        if not is_sidebar(win) and vim.api.nvim_win_get_config(win).relative == "" then
            return win
        end
    end
    vim.cmd("new")
    return vim.api.nvim_get_current_win()
end

local function open_start_page()
    if busy then
        return
    end
    -- Already visible in some window: never paint a second start page.
    if #alpha_windows() > 0 then
        return
    end
    if not only_scratch_buffers() then
        return
    end
    local target = editor_window()
    busy = true
    pcall(function()
        vim.api.nvim_set_current_win(target)
        require("alpha").start(false)
    end)

    -- Deleting the last buffer makes Neovim create a replacement empty buffer.
    -- Purge those so no phantom "No Name" tab is left in the tab bar.
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if
            vim.api.nvim_buf_is_valid(buf)
            and vim.bo[buf].buflisted
            and vim.api.nvim_buf_get_name(buf) == ""
            and vim.bo[buf].buftype == ""
            and vim.bo[buf].filetype == ""
            and buf ~= vim.api.nvim_get_current_buf()
        then
            for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
                local bufs = vim.t[tab].bufs
                if bufs then
                    vim.t[tab].bufs = vim.tbl_filter(function(nr)
                        return nr ~= buf and vim.api.nvim_buf_is_valid(nr)
                    end, bufs)
                end
            end
            pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
    end
    pcall(vim.cmd, "redrawtabline")
    busy = false
end

--- Show the start page when there is nothing else to show. Called from the
--- session layer when no session was restored for this directory, and from the
--- BufDelete hook after the last real buffer is closed.
function M.start()
    open_start_page()
end

function M.setup()
    dashboard()

    vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
        group = vim.api.nvim_create_augroup("DashboardAfterLastBuffer", { clear = true }),
        callback = function(args)
            if busy then
                return
            end
            local ok, ft = pcall(function()
                return vim.bo[args.buf].filetype
            end)
            if ok and ft == "alpha" then
                return
            end
            vim.schedule(open_start_page)
        end,
        desc = "Show the start page when the last buffer is closed",
    })

    -- Re-theme the page after a live theme switch.
    vim.api.nvim_create_autocmd("User", {
        group = vim.api.nvim_create_augroup("DashboardThemeRefresh", { clear = true }),
        pattern = "NvThemeReload",
        callback = function()
            local alpha = package.loaded["alpha"]
            if alpha and vim.bo.filetype == "alpha" then
                pcall(alpha.redraw)
            end
        end,
        desc = "Redraw the start page after a theme change",
    })
end

return M
