require("nvchad.mappings")

local map = vim.keymap.set
local opts = { noremap = true, silent = true }
local ide = require("configs.ide")

-- ---------------------------------------------------------------------------
-- Remove NvChad defaults that conflict with the IDE layer or Zed keybindings.
-- ---------------------------------------------------------------------------
local function del(mode, lhs)
    pcall(vim.keymap.del, mode, lhs)
end

del("n", "<leader>n") -- line numbers: moved to <leader>un
del("n", "<leader>rn") -- relative numbers: moved to <leader>ur
del("n", "<leader>h") -- horizontal terminal: harpoon prefix
del("n", "<leader>v") -- vertical terminal: view prefix
del("n", "<leader>b") -- new buffer: breakpoint
del("n", "<leader>x") -- close buffer: Lazy
del("n", "<leader>ra") -- NvChad renamer: rename is <leader>rn / <leader>rv
del("n", "<C-n>") -- NvimTreeToggle: project panel is <leader>e / <A-e>
del("n", "<A-i>") -- float terminal: completion is <A-i>, float terminal is <A-;>
del("n", "<A-v>") -- vertical terminal: split vertical
del("n", "<A-h>") -- horizontal terminal: split horizontal
del("n", "<A-d>") -- NvimTreeClose: outline / right dock
del("n", "<leader>th") -- re-added below with the same action and a stable description
del("n", "<leader>wa") -- NvChad LSP workspace mapping: replaced by session mappings
del("n", "<leader>wk") -- which-key query: avoid delaying the <leader>w save map
del("n", "<leader>wK") -- which-key all-keymaps: avoid delaying the <leader>w save map

-- ---------------------------------------------------------------------------
-- Tiny helpers
-- ---------------------------------------------------------------------------
local function load_plugin(name)
    local ok = pcall(require, name)
    if not ok then
        pcall(function()
            require("lazy").load({ plugins = { name } })
        end)
    end
end

local function telescope(picker, picker_opts)
    load_plugin("telescope.nvim")
    local builtin = require("telescope.builtin")
    builtin[picker](picker_opts or {})
end

local function load_format_module()
    load_plugin("conform.nvim")
    local ok, formatter = pcall(require, "configs.conform")
    if not ok then
        return nil
    end
    return formatter
end

local function format_buffer()
    local formatter = load_format_module()
    if not formatter then
        vim.notify("conform.nvim is not available", vim.log.levels.ERROR)
        return
    end
    formatter.format()
end

local function format_and_save()
    local bufnr = vim.api.nvim_get_current_buf()
    local formatter = load_format_module()
    if formatter then
        formatter.format(bufnr, { timeout_ms = 2500 })
    else
        pcall(vim.lsp.buf.format, { timeout_ms = 2500 })
    end

    -- The buffer is already formatted, so keep the format-on-save autocmd from
    -- running the formatter a second time and moving the cursor again.
    local previous = vim.b[bufnr].disable_autoformat
    vim.b[bufnr].disable_autoformat = true
    local write_ok, write_err = pcall(vim.cmd, "silent! write")
    vim.b[bufnr].disable_autoformat = previous

    if not write_ok then
        vim.notify("Write failed: " .. tostring(write_err), vim.log.levels.ERROR)
    elseif formatter then
        vim.notify("Formatted & saved", vim.log.levels.INFO)
    else
        vim.notify("Saved", vim.log.levels.INFO)
    end
end

local function save_without_format()
    local bufnr = vim.api.nvim_get_current_buf()
    local previous = vim.b[bufnr].disable_autoformat
    vim.b[bufnr].disable_autoformat = true
    local ok, err = pcall(vim.cmd, "silent! write")
    vim.b[bufnr].disable_autoformat = previous
    if not ok then
        vim.notify("Write failed: " .. tostring(err), vim.log.levels.ERROR)
    else
        vim.notify("Saved without formatting", vim.log.levels.INFO)
    end
end

local function new_file()
    local default = vim.fn.getcwd() .. "/"
    vim.ui.input({ prompt = "New file: ", default = default, completion = "file" }, function(input)
        if not input or input == "" then
            return
        end
        vim.cmd("edit " .. vim.fn.fnameescape(input))
    end)
end

local function reveal_in_file_manager()
    local dir = vim.fn.expand("%:p:h")
    if dir == "" or vim.fn.isdirectory(dir) == 0 then
        dir = vim.fn.getcwd()
    end
    local cmd
    if vim.fn.executable("thunar") == 1 then
        cmd = "thunar"
    elseif vim.fn.executable("xdg-open") == 1 then
        cmd = "xdg-open"
    end
    if not cmd then
        vim.notify("No file manager launcher found", vim.log.levels.WARN)
        return
    end
    vim.fn.jobstart({ cmd, dir }, { detach = true })
end

local function toggle_fullscreen()
    if vim.env.SWAYSOCK then
        vim.fn.system("swaymsg fullscreen toggle")
    elseif vim.fn.executable("i3-msg") == 1 then
        vim.fn.system("i3-msg fullscreen toggle")
    elseif vim.g.neovide then
        vim.cmd("set guifullscreen!")
    else
        vim.notify("Fullscreen toggle is not available in this environment", vim.log.levels.WARN)
    end
end

local function edit_config(path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
end

-- ---------------------------------------------------------------------------
-- Insert / terminal basics
-- ---------------------------------------------------------------------------
map("i", "jk", "<Esc>", { desc = "Escape insert mode" })
map("i", ";w", "<Esc>:write<CR>", { desc = "Write file" })
map("i", ";x", "<Esc>:wq<CR>", { desc = "Write and quit" })
map({ "n", "t", "i" }, "<A-;>", "<cmd>ToggleTerm direction=horizontal<CR>", { desc = "Toggle integrated terminal" })
map({ "n", "t", "i" }, "<C-;>", "<cmd>ToggleTerm direction=horizontal<CR>", { desc = "Toggle integrated terminal" })
map("t", "<C-h>", [[<C-\><C-n><C-w>h]], { desc = "Focus window left" })
map("t", "<C-j>", [[<C-\><C-n><C-w>j]], { desc = "Focus window down" })
map("t", "<C-k>", [[<C-\><C-n><C-w>k]], { desc = "Focus window up" })
map("t", "<C-l>", [[<C-\><C-n><C-w>l]], { desc = "Focus window right" })
map("i", "<C-m>", "<C-R>+", { desc = "Paste clipboard" })

-- ---------------------------------------------------------------------------
-- Motion and viewport centering
-- ---------------------------------------------------------------------------
map("n", "j", "jzz", opts)
map("n", "k", "kzz", opts)
map({ "n", "v" }, "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
map({ "n", "v" }, "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })
map({ "n", "v" }, "<C-f>", "<C-f>zz", { desc = "Page down and center" })
map({ "n", "v" }, "<C-b>", "<C-b>zz", { desc = "Page up and center" })
map({ "n", "v" }, "}", "}zz", { desc = "Next paragraph and center" })
map({ "n", "v" }, "{", "{zz", { desc = "Previous paragraph and center" })
map({ "n", "v" }, "G", "Gzz", { desc = "End of buffer and center" })
map({ "n", "v" }, "gg", "ggzz", { desc = "Start of buffer and center" })
map({ "n", "v" }, "%", "%zz", { desc = "Matching bracket and center" })
map("n", "n", "nzzzv", { desc = "Next search match and center" })
map("n", "N", "Nzzzv", { desc = "Previous search match and center" })
map("n", "*", "*zzzv", { desc = "Search word forward and center" })
map("n", "#", "#zzzv", { desc = "Search word backward and center" })
map("n", "g*", "g*zzzv", { desc = "Search word forward and center" })
map("n", "g#", "g#zzzv", { desc = "Search word backward and center" })
map("n", "<C-o>", "<C-o>zz", { desc = "Jump back and center" })
map("n", "<C-i>", "<C-i>zz", { desc = "Jump forward and center" })
map("n", "g;", "g;zz", { desc = "Previous change and center" })
map("n", "g,", "g,zz", { desc = "Next change and center" })
map("n", "p", "pzz", { desc = "Paste and center" })
map("n", "P", "Pzz", { desc = "Paste before and center" })
map("n", "gp", 'o<Esc>"+p', { desc = "Paste below on a new line" })
map("n", "gP", 'O<Esc>"+P', { desc = "Paste above on a new line" })
map("n", "U", "<C-r>", { desc = "Redo" })
map("n", "+", "<C-a>", { desc = "Increment number" })
map("n", "-", "<C-x>", { desc = "Decrement number" })

-- Black-hole deletes and clipboard yanks. Keep native d/c operators responsive.
map("n", "C", '"_C', opts)
map("n", "x", '"_x', opts)
map("n", "X", '"_X', opts)
map("x", "d", '"_d', opts)
map("x", "D", '"_D', opts)
map("x", "c", '"_c', opts)
map("x", "C", '"_C', opts)
map("x", "p", '"_dP', { desc = "Paste without overwriting the register" })
map("x", "y", '"+y', { desc = "Yank selection to clipboard" })
map("x", "<leader>y", '"+y', { desc = "Yank selection to clipboard" })
map("n", "yy", '"+yy', { desc = "Yank line to clipboard" })

-- Zed increment/decrement and copy/paste aliases
map("n", "<leader>sa", "ggVG", { desc = "Select all" })
map("n", "<leader>da", 'ggVG"_d', { desc = "Delete all" })
map("n", "<leader>ya", 'ggVG"+y', { desc = "Yank all to clipboard" })
map("n", "<leader>yf", 'ggVG"+y', { desc = "Select all and copy" })
map("n", "<leader>yy", function()
    ide.copy_path(false)
end, { desc = "Copy absolute path" })
map("n", "<leader>cp", function()
    ide.copy_path(false)
end, { desc = "Copy absolute path" })
map("n", "<leader>cn", function()
    ide.copy_path(true)
end, { desc = "Copy relative path" })
map("n", "<leader>sh", ide.print_path, { desc = "Print current file path" })

-- Line editing helpers
map("n", "<leader>j", "mzJ`z", { desc = "Join lines and keep cursor" })
map("n", "<leader>/", "gcc", { remap = true, desc = "Toggle comment" })
map("x", "<leader>/", "gc", { remap = true, desc = "Toggle comment" })
map("n", "<leader><CR>", "o<Esc>", { desc = "New line below" })
map("n", "<leader>;", "mzA;<Esc>`z", { desc = "Append semicolon" })
map("n", "<leader>d;", ":s/;$//<CR>", { desc = "Remove trailing semicolon" })
map("n", "<leader>d,", ":s/,$//<CR>", { desc = "Remove trailing comma" })
map("n", "<leader>nk", "O<Esc>", { desc = "New line above" })
map("n", "<leader>N", "O<Esc>", { desc = "New line above" })
map("n", "<leader>nn", "o<Esc>", { desc = "New line below" })
map("n", "<leader>nf", new_file, { desc = "New file" })
map("n", "<leader>fn", new_file, { desc = "New file" })
map("v", "<", "<gv", { desc = "Indent left and reselect" })
map("v", ">", ">gv", { desc = "Indent right and reselect" })
map("v", "J", ":m .+1<CR>==zz", { desc = "Move selection down" })
map("v", "K", ":m .-2<CR>==zz", { desc = "Move selection up" })

-- ---------------------------------------------------------------------------
-- Splits, panes, buffers
-- ---------------------------------------------------------------------------
map("n", "<C-h>", "<C-w>h", { desc = "Focus left pane" })
map("n", "<C-j>", "<C-w>j", { desc = "Focus bottom pane" })
map("n", "<C-k>", "<C-w>k", { desc = "Focus top pane" })
map("n", "<C-l>", "<C-w>l", { desc = "Focus right pane" })
map("n", "<A-v>", ":vsplit<CR>", { desc = "Split vertical" })
map("n", "<A-h>", ":split<CR>", { desc = "Split horizontal" })
map("n", "<leader>gv", ":vsplit<CR>", { desc = "Split vertical" })
map("n", "<leader>gH", ":split<CR>", { desc = "Split horizontal" })
map("n", "<S-Right>", ":vertical resize +5<CR>", { desc = "Resize pane right" })
map("n", "<S-Left>", ":vertical resize -5<CR>", { desc = "Resize pane left" })
map("n", "<S-Down>", ":resize +5<CR>", { desc = "Resize pane down" })
map("n", "<S-Up>", ":resize -5<CR>", { desc = "Resize pane up" })

map("n", "<S-j>", function()
    require("nvchad.tabufline").next()
end, { desc = "Next buffer" })
map("n", "<S-k>", function()
    require("nvchad.tabufline").prev()
end, { desc = "Previous buffer" })
map("n", "<A-j>", function()
    require("nvchad.tabufline").next()
end, { desc = "Next buffer" })
map("n", "<A-k>", function()
    require("nvchad.tabufline").prev()
end, { desc = "Previous buffer" })
map("n", "<A-w>", function()
    require("nvchad.tabufline").close_buffer()
end, { desc = "Close buffer" })
map("n", "<leader>q", function()
    require("nvchad.tabufline").close_buffer()
end, { desc = "Close buffer" })
map("n", "<leader>Q", ":qa<CR>", { desc = "Quit all" })
map("n", "<leader><Tab>", "<cmd>qa!<CR>", { desc = "Force quit all" })
map("n", "<leader>dd", function()
    require("nvchad.tabufline").close_buffer()
end, { desc = "Close buffer" })
map("n", "<leader>df", function()
    require("nvchad.tabufline").close_buffer()
end, { desc = "Close buffer" })
map("n", "<leader>ct", ":lua require('nvchad.tabufline').closeAllBufs(false)<CR>", { desc = "Close inactive buffers" })
map("n", "<leader>cl", ":lua require('nvchad.tabufline').closeBufs_at_direction('left')<CR>", { desc = "Close buffers left" })
map("n", "<leader>cr", ":lua require('nvchad.tabufline').closeBufs_at_direction('right')<CR>", { desc = "Close buffers right" })
map("n", "<leader><leader>", ide.alternate_file, { desc = "Alternate buffer" })
map("n", "<leader>,", function()
    telescope("buffers")
end, { desc = "Buffer switcher" })
map("n", "<leader>rc", ide.reopen_closed, { desc = "Reopen closed item" })
map("n", "<A-Left>", ":lua require('nvchad.tabufline').move_buf(-1)<CR>", { desc = "Move buffer left" })
map("n", "<A-Right>", ":lua require('nvchad.tabufline').move_buf(1)<CR>", { desc = "Move buffer right" })

-- ---------------------------------------------------------------------------
-- Files, project tree, command palette
-- ---------------------------------------------------------------------------
map("n", "<leader>e", ":NvimTreeToggle<CR>", { desc = "Toggle project panel" })
map("n", "<A-e>", ":NvimTreeToggle<CR>", { desc = "Toggle project panel" })
map("n", "<A-l>", ":NvimTreeToggle<CR>", { desc = "Toggle project panel" })
map("n", "<leader>ge", ":NvimTreeToggle<CR>", { desc = "Toggle project panel" })
map("n", "<A-d>", ":Outline<CR>", { desc = "Toggle outline" })
map("n", "<leader>cs", ":Outline<CR>", { desc = "Toggle outline" })
map("n", "<A-p>", function()
    telescope("commands")
end, { desc = "Command palette" })
map("n", "<A-f>", function()
    telescope("find_files")
end, { desc = "File finder" })
map("n", "<leader>of", function()
    telescope("find_files")
end, { desc = "Open file" })
map("n", "<leader>oe", reveal_in_file_manager, { desc = "Reveal in file manager" })

-- ---------------------------------------------------------------------------
-- Telescope / search
-- ---------------------------------------------------------------------------
map("n", "<leader>ff", function()
    telescope("find_files")
end, { desc = "Find files" })
map("n", "<leader>fg", function()
    telescope("live_grep")
end, { desc = "Live grep" })
map("n", "<leader>fw", function()
    telescope("live_grep")
end, { desc = "Live grep" })
map("n", "<leader>fb", function()
    telescope("buffers")
end, { desc = "Buffers" })
local function zoxide_fly(opts)
    opts = opts or {}
    load_plugin("telescope.nvim")
    local pickers = require("telescope.pickers")
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    vim.system({ "zoxide", "query", "-l" }, { text = true }, function(obj)
        local dirs = {}
        if obj.code == 0 and obj.stdout then
            for line in obj.stdout:gmatch("[^\r\n]+") do
                if line ~= "" then
                    table.insert(dirs, line)
                end
            end
        end

        vim.schedule(function()
            pickers.new(opts, {
                prompt_title = false,
                results_title = false,
                finder = finders.new_table({
                    results = dirs,
                }),
                sorter = conf.generic_sorter(opts),
                attach_mappings = function(prompt_bufnr, map)
                    local function open_dir_files()
                        local selection = action_state.get_selected_entry()
                        actions.close(prompt_bufnr)
                        if not selection then return end
                        local target_dir = selection[1]
                        vim.cmd("silent! cd " .. vim.fn.fnameescape(target_dir))
                        require("telescope.builtin").find_files({
                            cwd = target_dir,
                            prompt_title = false,
                        })
                    end

                    local function cd_and_tree()
                        local selection = action_state.get_selected_entry()
                        actions.close(prompt_bufnr)
                        if not selection then return end
                        local target_dir = selection[1]
                        vim.cmd("cd " .. vim.fn.fnameescape(target_dir))
                        vim.notify("CWD changed to: " .. target_dir)
                        pcall(function()
                            require("nvim-tree.api").tree.open({ path = target_dir })
                        end)
                        pcall(function()
                            require("configs.ide").cleanup_empty_unnamed_bufs()
                        end)
                    end

                    local function open_in_yazi()
                        local selection = action_state.get_selected_entry()
                        actions.close(prompt_bufnr)
                        if not selection then return end
                        local target_dir = selection[1]
                        pcall(function()
                            require("yazi").yazi(nil, target_dir)
                        end)
                    end

                    actions.select_default:replace(open_dir_files)
                    map("i", "<C-d>", cd_and_tree)
                    map("n", "<C-d>", cd_and_tree)
                    map("i", "<C-y>", open_in_yazi)
                    map("n", "<C-y>", open_in_yazi)
                    return true
                end,
            }):find()
        end)
    end)
end

map("n", "<leader>fo", function()
    telescope("oldfiles")
end, { desc = "Recent files" })
map("n", "<leader>fh", function()
    telescope("help_tags")
end, { desc = "Help tags" })
map("n", "<leader>fz", zoxide_fly, { desc = "Zoxide fly (quick jump & open files)" })
map("n", "<leader>cd", zoxide_fly, { desc = "Zoxide fly (quick jump & open files)" })
map("n", "<leader>fl", function()
    telescope("current_buffer_fuzzy_find")
end, { desc = "Fuzzy find lines in buffer" })
map("n", "<leader>fa", function()
    telescope("find_files", { hidden = true })
end, { desc = "Find all files" })
map("n", "<leader>fr", function()
    telescope("resume")
end, { desc = "Resume last picker" })
map("n", "<leader>ss", function()
    telescope("live_grep", { grep_open_files = true, prompt_title = "Live Grep in Open Files" })
end, { desc = "Live grep in open files" })
map("n", "<leader>sk", function()
    telescope("keymaps")
end, { desc = "Keymaps" })
map("n", "<leader>sc", function()
    telescope("commands")
end, { desc = "Commands" })
map("n", "<leader>oc", function()
    telescope("find_files", { cwd = vim.fn.stdpath("config") })
end, { desc = "Open config files" })
map("n", "<leader>oG", function()
    telescope("live_grep", { cwd = vim.fn.stdpath("config") })
end, { desc = "Grep config files" })

-- ---------------------------------------------------------------------------
-- Settings, sessions, tasks
-- ---------------------------------------------------------------------------
map("n", "<leader>os", function()
    edit_config(vim.fn.stdpath("config") .. "/init.lua")
end, { desc = "Open settings file" })
map("n", "<leader>og", function()
    edit_config(vim.fn.stdpath("config") .. "/lua/chadrc.lua")
end, { desc = "Open UI settings" })
map("n", "<leader>ok", function()
    edit_config(vim.fn.stdpath("config") .. "/lua/mappings.lua")
end, { desc = "Open keymap file" })
map("n", "<leader>om", ide.open_roadmap, { desc = "Open roadmap" })
map("n", "<leader>or", ":SessionSearch<CR>", { desc = "Recent sessions" })
map("n", "<leader>oR", ":SessionSearch<CR>", { desc = "Recent sessions" })
map("n", "<leader>oS", ":SessionSave<CR>", { desc = "Save session" })
map("n", "<leader>oA", ":SessionToggleAutoSave<CR>", { desc = "Toggle session autosave" })
map("n", "<leader>oi", ide.view_image, { desc = "View image (imv / chafa)" })
map("n", "<leader>vi", ide.view_image, { desc = "View image (imv / chafa)" })
map("n", "<A-r>", ide.run_file, { desc = "Run current file" })
map("n", "<leader>rt", ide.task_menu, { desc = "Task picker" })
map("n", "<leader>rr", ide.rerun, { desc = "Rerun last task" })
map("n", "<leader>rf", ide.run_file, { desc = "Run current file" })
map("n", "<leader>rp", ide.run_project, { desc = "Run project" })
map("n", "<leader>rC", ide.run_close, { desc = "Close code runner" })
map("n", "<leader>ls", ide.live_server, { desc = "Live server" })
map("n", "<leader>nd", ide.npm_dev, { desc = "npm run dev" })

-- ---------------------------------------------------------------------------
-- Save / format
-- ---------------------------------------------------------------------------
map({ "n", "v" }, "<C-s>", format_and_save, { desc = "Format and save" })
map({ "n", "v" }, "<leader>w", format_and_save, { desc = "Format and save" })
map({ "n", "v" }, "<leader>W", save_without_format, { desc = "Save without formatting" })
map({ "n", "v" }, "<leader>fd", format_buffer, { desc = "Format document" })
map({ "n", "v" }, "<leader>fm", format_buffer, { desc = "Format document" })

-- ---------------------------------------------------------------------------
-- View / UI
-- ---------------------------------------------------------------------------
map("n", "<leader>th", function()
    require("nvchad.themes").open({ border = true })
end, { desc = "Theme selector" })
map("n", "<leader>ts", ":Telescope colorscheme<CR>", { desc = "Colorschemes" })
map("n", "<leader>tc", "<cmd>Huefy<CR>", { desc = "Minty color picker (Huefy)" })
map("n", "<leader>tC", "<cmd>Shades<CR>", { desc = "Minty color shades" })
map("n", "<C-t>", function()
    require("menu").open("default")
end, { desc = "Open context menu" })
map({ "n", "v" }, "<RightMouse>", function()
    require("menu.utils").delete_old_menus()
    vim.cmd.exec('"normal! \\<RightMouse>"')
    local buf = vim.api.nvim_win_get_buf(vim.fn.getmousepos().winid)
    local options = vim.bo[buf].ft == "NvimTree" and "nvimtree" or "default"
    require("menu").open(options, { mouse = true })
end, { desc = "Open right-click menu" })
map("n", "<leader>un", ide.toggle_number, { desc = "Toggle line numbers" })
map("n", "<leader>ur", ide.toggle_relativenumber, { desc = "Toggle relative numbers" })
map("n", "<leader>uw", ide.toggle_wrap, { desc = "Toggle soft wrap" })
map("n", "<leader>ua", ide.toggle_autosave, { desc = "Toggle autosave" })
map("n", "<leader>us", function()
    require("configs.statusline").toggle()
end, { desc = "Toggle statusline" })
map("n", "<leader>ih", ide.toggle_inlay_hints, { desc = "Toggle inlay hints" })
map("n", "<leader>zf", toggle_fullscreen, { desc = "Toggle fullscreen" })
map("n", "<leader>x", ":Lazy<CR>", { desc = "Extensions / plugins" })
map("n", "<leader>xm", ":Mason<CR>", { desc = "Mason packages" })
map("n", "<leader>xs", ":Lazy sync<CR>", { desc = "Sync plugins" })
map("n", "<leader>xu", ":Lazy update<CR>", { desc = "Update plugins" })
map("n", "<leader>xc", ":Lazy clean<CR>", { desc = "Clean plugins" })
map("n", "<leader>Ls", ":Lazy sync<CR>", { desc = "Sync plugins" })

-- ---------------------------------------------------------------------------
-- Git
-- ---------------------------------------------------------------------------
map("n", "<leader>gt", function()
    telescope("git_status")
end, { desc = "Git status" })
map("n", "<leader>gl", function()
    telescope("git_commits")
end, { desc = "Git commits" })
map("n", "<leader>gb", function()
    telescope("git_branches")
end, { desc = "Git branches" })
map("n", "<leader>gf", function()
    telescope("git_files")
end, { desc = "Git files" })
map("n", "<leader>gq", ":Trouble toggle<CR>", { desc = "Toggle right dock" })

-- ---------------------------------------------------------------------------
-- Diagnostics
-- ---------------------------------------------------------------------------
map("n", "]d", function()
    vim.diagnostic.jump({ count = 1, float = true })
end, { desc = "Next diagnostic" })
map("n", "[d", function()
    vim.diagnostic.jump({ count = -1, float = true })
end, { desc = "Previous diagnostic" })
map("n", "<leader>vp", ":Trouble diagnostics toggle<CR>", { desc = "Diagnostics panel" })
map("n", "<leader>pe", ":Trouble diagnostics toggle<CR>", { desc = "Deploy diagnostics" })
map("n", "<leader>vq", ":Trouble qflist toggle<CR>", { desc = "Quickfix panel" })
map("n", "<leader>xx", ":Trouble diagnostics toggle<CR>", { desc = "Diagnostics panel" })

-- ---------------------------------------------------------------------------
-- Zed-style code navigation helpers (LSP buffer maps live in configs/ide.lua)
-- ---------------------------------------------------------------------------
map("n", "g f", "gf", { remap = true, desc = "Open file under cursor" })
map("x", "g f", ide.open_filename, { desc = "Open selected filename" })
map("n", "g x", ide.open_url, { desc = "Open URL under cursor" })
map("n", "g z", ide.open_url, { desc = "Open URL under cursor" })
-- g l / g L / g a are owned by lua/plugins/multicursor.lua (Zed parity).
map("n", "g A", function()
    telescope("lsp_references")
end, { desc = "Find references" })
map("n", "g s", "s", { remap = true, desc = "Jump to word (sneak)" })
map("n", "g S", "S", { remap = true, desc = "Jump to word backward (sneak)" })
map("n", "g c", "gcc", { remap = true, desc = "Toggle comment" })
map("x", "g c", "gc", { remap = true, desc = "Toggle comment" })
map("n", "<C-/>", "gcc", { remap = true, desc = "Toggle comment" })
map("x", "<C-/>", "gc", { remap = true, desc = "Toggle comment" })
map("n", "<leader>cS", function()
    telescope("lsp_workspace_symbols")
end, { desc = "Workspace symbols" })
