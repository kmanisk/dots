-- IDE behaviour layer: diagnostics, LSP keymaps, autosave, save hygiene, tasks.
-- Kept free of plugin-specific setup so it loads in a few milliseconds.

local M = {}

local api = vim.api
local fn = vim.fn

-- ---------------------------------------------------------------------------
-- Diagnostics
-- ---------------------------------------------------------------------------
local orig_publish_diagnostics = vim.lsp.handlers["textDocument/publishDiagnostics"]
vim.lsp.handlers["textDocument/publishDiagnostics"] = function(err, result, ctx, config)
    if result and result.diagnostics then
        local filtered = {}
        for _, diag in ipairs(result.diagnostics) do
            local msg = diag.message or ""
            -- Filter out the noisy Eclipse jdtls non-project file warning
            if not msg:find("non%-project file, only syntax errors are reported") then
                table.insert(filtered, diag)
            end
        end
        result.diagnostics = filtered
    end
    if orig_publish_diagnostics then
        orig_publish_diagnostics(err, result, ctx, config)
    else
        vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx, config)
    end
end

vim.diagnostic.config({
    virtual_text = {
        severity = { min = vim.diagnostic.severity.ERROR },
        spacing = 2,
        prefix = ">>",
        source = "if_many",
    },
    signs = {
        severity = { min = vim.diagnostic.severity.ERROR },
    },
    underline = {
        severity = { min = vim.diagnostic.severity.ERROR },
    },
    update_in_insert = false,
    severity_sort = true,
    float = {
        border = "single",
        source = true,
        header = "",
        prefix = "",
    },
})

-- ---------------------------------------------------------------------------
-- LSP attach keymaps (Zed-compatible where it does not break Vim essentials)
-- ---------------------------------------------------------------------------
local function split_jump(jump)
    return function()
        vim.cmd("split")
        jump()
    end
end

function M.on_attach(client, bufnr)
    -- Remove NvChad's legacy buffer-local workspace/rename mappings so they
    -- do not shadow session, DAP, or Zed-compatible keys.
    for _, lhs in ipairs({ "<leader>wa", "<leader>wr", "<leader>wl", "<leader>D", "<leader>ra" }) do
        pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
    end

    local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
    end

    map("n", "gd", vim.lsp.buf.definition, "LSP: go to definition")
    map("n", "gD", split_jump(vim.lsp.buf.definition), "LSP: go to definition (split)")
    map("n", "gi", vim.lsp.buf.implementation, "LSP: go to implementation")
    map("n", "gI", split_jump(vim.lsp.buf.implementation), "LSP: go to implementation (split)")
    map("n", "gt", vim.lsp.buf.type_definition, "LSP: go to type definition")
    map("n", "gT", split_jump(vim.lsp.buf.type_definition), "LSP: go to type definition (split)")
    map("n", "K", vim.lsp.buf.hover, "LSP: hover")
    map("n", "<leader>cD", vim.lsp.buf.declaration, "LSP: go to declaration")
    -- actions-preview shows the resulting diff of each code action, which
    -- matters for jdtls (extract variable/method, generate, surround). Fall
    -- back to the stock picker if the plugin is unavailable.
    local function code_action()
        local ok, preview = pcall(require, "actions-preview")
        if ok then
            preview.code_actions()
        else
            vim.lsp.buf.code_action()
        end
    end

    map("n", "<leader>ca", code_action, "LSP: code action")
    map("v", "<leader>ca", code_action, "LSP: code action")
    map("n", "<leader>rn", vim.lsp.buf.rename, "LSP: rename symbol")
    map("n", "<leader>rv", vim.lsp.buf.rename, "LSP: rename symbol")
    map("n", "<leader>co", function()
        vim.lsp.buf.code_action({
            apply = true,
            context = { only = { "source.organizeImports" }, diagnostics = {} },
        })
    end, "LSP: organize imports")
    -- gR, not gr: stock Neovim 0.11 owns the gr* family (grn rename,
    -- gra code action, grr references, gri implementations, grt types).
    map("n", "gR", function()
        local ok, builtin = pcall(require, "telescope.builtin")
        if ok then
            builtin.lsp_references()
        else
            vim.lsp.buf.references()
        end
    end, "LSP: references")
    map("n", "<leader>ds", vim.diagnostic.setloclist, "Diagnostics: location list")

    if client and client.supports_method and client:supports_method("textDocument/inlayHint") then
        map("n", "<leader>ih", M.toggle_inlay_hints, "LSP: toggle inlay hints")
    end
end

-- ---------------------------------------------------------------------------
-- Buffer closing
-- ---------------------------------------------------------------------------
-- nvchad.tabufline.close_buffer runs :bnext/:bdelete on the current window.
-- Inside the command-line window (q:) those commands raise
-- "E11: Invalid in command-line window", so leave the cmdwin first. Wrapping the
-- module keeps every caller safe, including the tabufline close button and the
-- <leader>q / <A-w> mappings.
do
    local ok, tabufline = pcall(require, "nvchad.tabufline")
    if ok and not tabufline._cmdwin_guard then
        tabufline._cmdwin_guard = true
        local close_buffer = tabufline.close_buffer

        tabufline.close_buffer = function(...)
            if fn.getcmdwintype() ~= "" then
                vim.cmd("quit")
                return
            end
            return close_buffer(...)
        end
    end
end

-- ---------------------------------------------------------------------------
-- Inlay hints
-- ---------------------------------------------------------------------------
function M.toggle_inlay_hints()
    local bufnr = api.nvim_get_current_buf()
    local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
    vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
    vim.notify("Inlay hints " .. (enabled and "disabled" or "enabled"), vim.log.levels.INFO)
end

-- ---------------------------------------------------------------------------
-- Path helpers
-- ---------------------------------------------------------------------------
function M.copy_path(relative)
    local path = relative and fn.expand("%:.") or fn.expand("%:p")
    if path == "" then
        vim.notify("No file in current buffer", vim.log.levels.WARN)
        return
    end
    vim.fn.setreg("+", path)
    vim.fn.setreg('"', path)
    vim.notify("Copied: " .. path, vim.log.levels.INFO)
end

function M.print_path()
    local path = fn.expand("%:p")
    if path == "" then
        vim.notify("No file in current buffer", vim.log.levels.WARN)
        return
    end
    vim.notify(path, vim.log.levels.INFO)
end

-- ---------------------------------------------------------------------------
-- Alternate buffer and reopen-closed
-- ---------------------------------------------------------------------------
function M.alternate_file()
    local nr = fn.bufnr("#")
    if nr == -1 or not api.nvim_buf_is_valid(nr) then
        vim.notify("No alternate buffer", vim.log.levels.WARN)
        return
    end
    vim.cmd("buffer " .. nr)
end

local closed_buffers = {}

api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = api.nvim_create_augroup("IdeClosedBuffers", { clear = true }),
    callback = function(args)
        local name = api.nvim_buf_get_name(args.buf)
        if name == "" or fn.filereadable(name) == 0 then
            return
        end
        if api.nvim_get_option_value("buftype", { buf = args.buf }) ~= "" then
            return
        end
        table.insert(closed_buffers, 1, name)
        if #closed_buffers > 20 then
            table.remove(closed_buffers)
        end
    end,
})

function M.reopen_closed()
    while #closed_buffers > 0 do
        local path = table.remove(closed_buffers, 1)
        if fn.filereadable(path) == 1 then
            vim.cmd("edit " .. fn.fnameescape(path))
            return
        end
    end
    vim.notify("No recently closed file", vim.log.levels.WARN)
end

-- ---------------------------------------------------------------------------
-- Open URL / file under cursor
-- ---------------------------------------------------------------------------
local function find_url(line)
    return line:match("https?://[%w%-%._~:/?#%[%]@!$&'()*+,;=]+")
end

function M.open_url()
    local url = find_url(api.nvim_get_current_line())
    if not url then
        vim.notify("No URL on current line", vim.log.levels.WARN)
        return
    end
    vim.ui.open(url)
end

local function visual_selection()
    local mode = fn.mode()
    if not mode:match("[vV\22]") then
        return ""
    end
    local ok, region = pcall(fn.getregion, fn.getpos("v"), fn.getpos("."), { type = mode })
    if not ok or type(region) ~= "table" then
        return ""
    end
    return vim.trim(table.concat(region, "\n"))
end

function M.open_filename()
    local target = visual_selection()
    if target == "" then
        target = fn.expand("<cfile>")
    end
    if target == "" then
        target = fn.expand("<cword>")
    end
    target = target:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^[\"']", ""):gsub("[\"']$", "")
    if target == "" then
        vim.notify("No filename under cursor", vim.log.levels.WARN)
        return
    end
    vim.cmd("edit " .. fn.fnameescape(target))
end

-- ---------------------------------------------------------------------------
-- Toggle helpers
-- ---------------------------------------------------------------------------
function M.toggle_wrap()
    vim.wo.wrap = not vim.wo.wrap
    vim.notify("Wrap " .. (vim.wo.wrap and "on" or "off"), vim.log.levels.INFO)
end

function M.toggle_number()
    vim.o.number = not vim.o.number
end

function M.toggle_relativenumber()
    vim.o.relativenumber = not vim.o.relativenumber
end

function M.toggle_autosave()
    vim.g.autosave_enabled = not vim.g.autosave_enabled
    vim.notify("Autosave " .. (vim.g.autosave_enabled and "enabled" or "disabled"), vim.log.levels.INFO)
end

-- ---------------------------------------------------------------------------
-- Tasks (Zed tasks parity)
-- ---------------------------------------------------------------------------
local function open_terminal(cmd)
    vim.cmd("botright split")
    vim.cmd("terminal " .. cmd)
    vim.cmd("startinsert")
end

local function project_root()
    local root = fn.getcwd()
    local git_dir = fn.finddir(".git", ".;")
    if git_dir ~= "" then
        return fn.fnamemodify(git_dir, ":p:h")
    end
    local markers = { "package.json", "Cargo.toml", "go.mod", "pyproject.toml", "pom.xml" }
    for _, marker in ipairs(markers) do
        local found = fn.findfile(marker, ".;")
        if found ~= "" then
            return fn.fnamemodify(found, ":p:h")
        end
    end
    return root
end

function M.live_server()
    local root = project_root()
    if fn.executable("live-server") == 1 then
        open_terminal("live-server --port=5500 --wait=150 " .. fn.fnameescape(root))
    elseif fn.executable("python3") == 1 then
        open_terminal("python3 -m http.server 5500 --directory " .. fn.fnameescape(root))
    else
        vim.notify("Neither live-server nor python3 is available", vim.log.levels.ERROR)
    end
end

function M.npm_dev()
    local package = fn.findfile("package.json", ".;")
    if package == "" then
        vim.notify("No package.json found", vim.log.levels.WARN)
        return
    end
    local root = fn.fnamemodify(package, ":p:h")
    vim.cmd("cd " .. fn.fnameescape(root))
    open_terminal("npm run dev")
end

function M.run_file()
    if vim.bo.modified then
        pcall(vim.cmd, "silent! write")
    end
    if fn.exists(":RunFile") == 2 then
        vim.cmd("RunFile")
    else
        vim.notify("code_runner is not available", vim.log.levels.ERROR)
    end

    -- Move focus to the terminal window and enter insert mode immediately
    vim.defer_fn(function()
        for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
            local buf = api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype == "terminal" then
                api.nvim_set_current_win(win)
                vim.cmd("startinsert")
                break
            end
        end
    end, 50)
end

function M.run_project()
    if fn.exists(":RunProject") == 2 then
        vim.cmd("RunProject")
    else
        vim.notify("code_runner is not available", vim.log.levels.ERROR)
    end
end

function M.run_close()
    if fn.exists(":RunClose") == 2 then
        pcall(vim.cmd, "RunClose")
    end
    local ok, toggleterm = pcall(require, "toggleterm")
    if ok then
        pcall(vim.cmd, "ToggleTermToggleAll")
    end
end

function M.view_image(target_path)
    target_path = target_path or fn.expand("%:p")
    if target_path == "" or fn.filereadable(target_path) ~= 1 then
        vim.notify("Image not found or not readable", vim.log.levels.WARN)
        return
    end

    local ext = fn.fnamemodify(target_path, ":e"):lower()
    local img_exts = { png = true, jpg = true, jpeg = true, webp = true, gif = true, svg = true, bmp = true, ico = true }
    if not img_exts[ext] then
        vim.notify("File is not a supported image: " .. ext, vim.log.levels.WARN)
        return
    end

    if fn.executable("imv") == 1 then
        fn.jobstart({ "imv", target_path }, { detach = true })
    elseif fn.executable("chafa") == 1 then
        vim.cmd("split | terminal chafa " .. fn.fnameescape(target_path))
    else
        vim.notify("Neither imv nor chafa is available", vim.log.levels.ERROR)
    end
end

function M.open_roadmap()
    local candidates = {
        fn.expand("~/coding/MasterRoadmap2026.md"),
        fn.expand("~/MasterRoadmap2026.md"),
        fn.expand("~/docs/MasterRoadmap2026.md"),
    }
    for _, path in ipairs(candidates) do
        if fn.filereadable(path) == 1 then
            vim.cmd("edit " .. fn.fnameescape(path))
            return
        end
    end
    vim.notify("MasterRoadmap2026.md not found", vim.log.levels.WARN)
end

local tasks = {
    { label = "Run current file", run = M.run_file },
    { label = "Run project", run = M.run_project },
    { label = "Live server", run = M.live_server },
    { label = "npm run dev", run = M.npm_dev },
    { label = "Open roadmap", run = M.open_roadmap },
}

local last_task = nil

function M.task_menu()
    vim.ui.select(tasks, {
        prompt = "Tasks",
        format_item = function(item)
            return item.label
        end,
    }, function(choice)
        if not choice then
            return
        end
        last_task = choice.run
        choice.run()
    end)
end

function M.rerun()
    if type(last_task) == "function" then
        last_task()
    else
        M.run_file()
    end
end

-- ---------------------------------------------------------------------------
-- Terminal navigation & clean minimal terminal window
-- ---------------------------------------------------------------------------
function M.setup_terminal_buffer(bufnr)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    -- Clean, minimal terminal buffer options. Terminal windows never render
    -- statusline content (see configs/statusline.lua); the bar itself is hidden
    -- globally by default with laststatus = 0.
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.opt_local.foldcolumn = "0"
    vim.opt_local.spell = false

    -- Distinct border colour for floating terminals so they never look like an
    -- ordinary float. Cleared again once the terminal stops being displayed.
    local term_win = vim.fn.bufwinid(bufnr)
    if term_win ~= -1 then
        vim.wo[term_win].winhighlight = "FloatBorder:SlTermBorder"
        vim.api.nvim_create_autocmd("BufWinLeave", {
            buffer = bufnr,
            once = true,
            callback = function()
                if vim.api.nvim_win_is_valid(term_win) then
                    vim.wo[term_win].winhighlight = ""
                end
            end,
            desc = "Clear the terminal border tint",
        })
    end

    -- Always enter insert mode
    vim.cmd("startinsert")

    -- 1. Direct window navigation in terminal mode without normal mode
    vim.keymap.set("t", "<C-h>", [[<C-\><C-n><C-w>h]], { buffer = bufnr, silent = true, desc = "Focus window left" })
    vim.keymap.set("t", "<C-j>", [[<C-\><C-n><C-w>j]], { buffer = bufnr, silent = true, desc = "Focus window down" })
    vim.keymap.set("t", "<C-k>", [[<C-\><C-n><C-w>k]], { buffer = bufnr, silent = true, desc = "Focus window up" })

    -- 2. Direct window navigation in normal mode (if focus was clicked or dropped out of insert)
    vim.keymap.set("n", "<C-h>", "<C-w>h", { buffer = bufnr, silent = true, desc = "Focus window left" })
    vim.keymap.set("n", "<C-j>", "<C-w>j", { buffer = bufnr, silent = true, desc = "Focus window down" })
    vim.keymap.set("n", "<C-k>", "<C-w>k", { buffer = bufnr, silent = true, desc = "Focus window up" })

    -- 3. <A-;> / <C-;> are left to the global ToggleTerm mapping so the key
    -- does the same thing everywhere (toggle, not a bare :close that fails on
    -- the last window). q still closes this window directly.
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = bufnr, silent = true, desc = "Close terminal" })

    -- 4. Terminal editing & mass deletion:
    -- In Neovim, <C-w> defaults to window prefix in terminal mode, stealing it from shells (fish/zsh/bash).
    -- Map <C-w> to send \x17 (Ctrl+W) so backward-delete-word works natively in the terminal.
    -- Map <C-u> to send \x15 (Ctrl+U) so mass delete / line clear works natively in the terminal.
    local function send_chan(bytes)
        local chan = vim.bo[bufnr].channel
        if chan and chan > 0 then
            pcall(vim.api.nvim_chan_send, chan, bytes)
        end
    end

    vim.keymap.set("t", "<C-w>", function()
        send_chan("\x17")
    end, { buffer = bufnr, silent = true, desc = "Delete word backward in terminal" })

    vim.keymap.set("t", "<C-u>", function()
        send_chan("\x15")
    end, { buffer = bufnr, silent = true, desc = "Mass delete line in terminal" })

    vim.keymap.set("n", "<C-w>", function()
        vim.cmd("startinsert")
        send_chan("\x17")
    end, { buffer = bufnr, silent = true, desc = "Delete word backward in terminal" })

    vim.keymap.set("n", "<C-u>", function()
        vim.cmd("startinsert")
        send_chan("\x15")
    end, { buffer = bufnr, silent = true, desc = "Mass delete line in terminal" })

    -- 4b. <C-l> clears the terminal instead of jumping to the right window:
    -- Ctrl+L goes to the shell (fish/zsh redraw, visible screen is dropped)
    -- and the buffer returns to terminal mode so typing continues.
    local function clear_terminal()
        if vim.api.nvim_get_mode().mode ~= "t" then
            vim.cmd("startinsert")
        end
        send_chan("\x0c")
    end

    vim.keymap.set("t", "<C-l>", clear_terminal, { buffer = bufnr, silent = true, desc = "Clear terminal" })
    vim.keymap.set("n", "<C-l>", clear_terminal, { buffer = bufnr, silent = true, desc = "Clear terminal" })

    -- 5. Typing helper: enter insert mode and send key directly to terminal channel
    -- Prevents vim-sneak (s/S), Harpoon, Hop, or standard vim normal mode commands
    -- from intercepting user keystrokes in terminal splits.
    local function send_and_insert(char)
        return function()
            vim.cmd("startinsert")
            if char and #char > 0 then
                local chan = vim.bo[bufnr].channel
                if chan and chan > 0 then
                    pcall(vim.api.nvim_chan_send, chan, char)
                end
            end
        end
    end

    -- Explicit overrides for sneak (s/S), z/Z, ;, ,, i, a, Enter, Space
    vim.keymap.set({ "n", "x", "o" }, "s", send_and_insert("s"), { buffer = bufnr, silent = true, nowait = true, desc = "Insert s" })
    vim.keymap.set({ "n", "x", "o" }, "S", send_and_insert("S"), { buffer = bufnr, silent = true, nowait = true, desc = "Insert S" })
    vim.keymap.set({ "n", "x", "o" }, "z", send_and_insert("z"), { buffer = bufnr, silent = true, nowait = true, desc = "Insert z" })
    vim.keymap.set({ "n", "x", "o" }, "Z", send_and_insert("Z"), { buffer = bufnr, silent = true, nowait = true, desc = "Insert Z" })
    vim.keymap.set({ "n", "x", "o" }, ";", send_and_insert(";"), { buffer = bufnr, silent = true, nowait = true, desc = "Insert ;" })
    vim.keymap.set({ "n", "x", "o" }, ",", send_and_insert(","), { buffer = bufnr, silent = true, nowait = true, desc = "Insert ," })
    vim.keymap.set({ "n", "x", "o" }, "i", send_and_insert(""), { buffer = bufnr, silent = true, nowait = true, desc = "Start insert" })
    vim.keymap.set({ "n", "x", "o" }, "a", send_and_insert(""), { buffer = bufnr, silent = true, nowait = true, desc = "Start insert" })
    vim.keymap.set({ "n", "x", "o" }, "I", send_and_insert(""), { buffer = bufnr, silent = true, nowait = true, desc = "Start insert" })
    vim.keymap.set({ "n", "x", "o" }, "A", send_and_insert(""), { buffer = bufnr, silent = true, nowait = true, desc = "Start insert" })
    vim.keymap.set({ "n", "x", "o" }, "<CR>", send_and_insert("\r"), { buffer = bufnr, silent = true, nowait = true, desc = "Insert Enter" })
    vim.keymap.set({ "n", "x", "o" }, "<Space>", send_and_insert(" "), { buffer = bufnr, silent = true, nowait = true, desc = "Insert space" })

    -- Map remaining printable characters to immediately enter insert mode
    local chars = "bcdefghjklmnoprtuvwxyBCDEFGHJKLMNOPRTUVWXY0123456789!@#$%^&*()_+-=[]{}|':\"./<>?`~"
    for i = 1, #chars do
        local c = chars:sub(i, i)
        vim.keymap.set({ "n", "x", "o" }, c, send_and_insert(c), { buffer = bufnr, silent = true, nowait = true })
    end
end

api.nvim_create_autocmd({ "TermOpen", "BufEnter", "WinEnter", "BufWinEnter" }, {
    group = api.nvim_create_augroup("IdeTerminalKeymaps", { clear = true }),
    callback = function(args)
        if vim.bo[args.buf].buftype ~= "terminal" and vim.bo[args.buf].filetype ~= "toggleterm" then
            return
        end
        M.setup_terminal_buffer(args.buf)
    end,
    desc = "Terminal minimal statusline, insert mode lock, and direct navigation",
})

-- ---------------------------------------------------------------------------
-- Save hygiene: trim trailing whitespace, keep final newline
-- ---------------------------------------------------------------------------
api.nvim_create_autocmd("BufWritePre", {
    group = api.nvim_create_augroup("IdeSaveHygiene", { clear = true }),
    callback = function()
        if api.nvim_get_option_value("buftype", { buf = 0 }) ~= "" then
            return
        end
        local filetype = api.nvim_get_option_value("filetype", { buf = 0 })
        if filetype == "markdown" or filetype == "mdx" or filetype == "gitcommit" then
            return
        end

        local mode = api.nvim_get_mode().mode
        local view = fn.winsaveview()
        if mode:find("^i") then
            -- While actively typing in insert mode, do not trim trailing spaces on the current line
            -- so cursor indentation is never wiped out underneath you by autosave
            local current_lnum = fn.line(".")
            local last = fn.line("$")
            if current_lnum > 1 then
                vim.cmd(string.format([[silent! keepjumps keeppatterns 1,%ds/\s\+$//e]], current_lnum - 1))
            end
            if current_lnum < last then
                vim.cmd(string.format([[silent! keepjumps keeppatterns %d,$s/\s\+$//e]], current_lnum + 1))
            end
        else
            vim.cmd([[silent! keepjumps keeppatterns %s/\s\+$//e]])
        end
        fn.winrestview(view)
    end,
    desc = "Trim trailing whitespace on save (preserving current active line in insert mode)",
})

-- ---------------------------------------------------------------------------
-- Autosave (Zed uses a 500 ms idle delay)
-- ---------------------------------------------------------------------------
if vim.g.autosave_enabled == nil then
    vim.g.autosave_enabled = true
end

local autosave_timers = {}
local autosave_skip = {
    help = true,
    lazy = true,
    mason = true,
    telescope = true,
    NvimTree = true,
    oil = true,
    yazi = true,
    toggleterm = true,
    qf = true,
    git = true,
    gitcommit = true,
    gitrebase = true,
    fugitive = true,
    NeogitConsole = true,
    Trouble = true,
    Outline = true,
    dap = true,
    dapui = true,
    ["dap-repl"] = true,
    ["dapui_console"] = true,
    ["dapui_watches"] = true,
    ["dapui_stacks"] = true,
    ["dapui_breakpoints"] = true,
    ["dapui_scopes"] = true,
    ["dapui_hover"] = true,
    ["snacks_"] = true,
}

local function should_autosave(buf)
    if not vim.g.autosave_enabled or not api.nvim_buf_is_valid(buf) then
        return false
    end
    local buftype = api.nvim_get_option_value("buftype", { buf = buf })
    local filetype = api.nvim_get_option_value("filetype", { buf = buf })
    local readonly = api.nvim_get_option_value("readonly", { buf = buf })
    local modified = api.nvim_get_option_value("modified", { buf = buf })
    local name = api.nvim_buf_get_name(buf)
    if buftype ~= "" or readonly or not modified or name == "" then
        return false
    end
    if autosave_skip[filetype] then
        return false
    end
    if filetype:match("^snacks_") or filetype:match("^dapui") then
        return false
    end
    return true
end

local function stop_autosave(buf)
    local timer = autosave_timers[buf]
    if timer then
        timer:stop()
        if not timer:is_closing() then
            timer:close()
        end
        autosave_timers[buf] = nil
    end
end

local function schedule_autosave(buf)
    if not should_autosave(buf) then
        return
    end
    local timer = autosave_timers[buf]
    if not timer then
        timer = vim.uv.new_timer()
        autosave_timers[buf] = timer
    end
    timer:stop()
    timer:start(1200, 0, vim.schedule_wrap(function()
        if not should_autosave(buf) then
            return
        end
        api.nvim_buf_call(buf, function()
            local old_disable = vim.b[buf].disable_autoformat
            vim.b[buf].disable_autoformat = true
            pcall(vim.cmd, "silent! write")
            vim.b[buf].disable_autoformat = old_disable
        end)
    end))
end

api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "InsertLeave" }, {
    group = api.nvim_create_augroup("IdeAutosave", { clear = true }),
    callback = function(args)
        schedule_autosave(args.buf)
    end,
    desc = "Autosave after 500 ms of inactivity",
})

api.nvim_create_autocmd({ "BufDelete", "BufWipeout", "VimLeavePre" }, {
    group = api.nvim_create_augroup("IdeAutosaveCleanup", { clear = true }),
    callback = function(args)
        stop_autosave(args.buf)
    end,
})

-- ---------------------------------------------------------------------------
-- Empty ghost "No Name" buffer purge engine
-- ---------------------------------------------------------------------------
local function is_empty_unnamed_buf(bufnr)
    if not api.nvim_buf_is_valid(bufnr) then
        return false
    end
    if api.nvim_buf_get_name(bufnr) ~= "" then
        return false
    end
    if vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].filetype ~= "" then
        return false
    end
    local lines = api.nvim_buf_get_lines(bufnr, 0, -1, false)
    return #lines <= 1 and (lines[1] == nil or lines[1]:match("^%s*$") ~= nil)
end

function M.cleanup_empty_unnamed_bufs()
    local valid_named = {}
    local empty_unnamed = {}
    for _, b in ipairs(api.nvim_list_bufs()) do
        if api.nvim_buf_is_valid(b) then
            if api.nvim_buf_get_name(b) ~= "" and vim.bo[b].buftype == "" then
                table.insert(valid_named, b)
            elseif is_empty_unnamed_buf(b) then
                table.insert(empty_unnamed, b)
            end
        end
    end
    if #valid_named > 0 and #empty_unnamed > 0 then
        for _, b in ipairs(empty_unnamed) do
            -- Strip from tabufline state for all tabs
            for _, tab in ipairs(api.nvim_list_tabpages()) do
                local bufs = vim.t[tab].bufs
                if bufs then
                    vim.t[tab].bufs = vim.tbl_filter(function(nr)
                        return nr ~= b and api.nvim_buf_is_valid(nr)
                    end, bufs)
                end
            end
            pcall(api.nvim_buf_delete, b, { force = true })
        end
        pcall(vim.cmd, "redrawtabline")
    end
end

api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "SessionLoadPost" }, {
    group = api.nvim_create_augroup("IdeCleanEmptyNoNameBufs", { clear = true }),
    callback = function(args)
        vim.schedule(function()
            if api.nvim_buf_is_valid(args.buf) and api.nvim_buf_get_name(args.buf) ~= "" and vim.bo[args.buf].buftype == "" then
                M.cleanup_empty_unnamed_bufs()
            end
        end)
    end,
    desc = "Purge empty unnamed buffers when real files or sessions are opened",
})

return M
