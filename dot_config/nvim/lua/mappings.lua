require("nvchad.mappings")

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
-- map("i", "<C-p>", "<C-r>+", opts)
-- map("i", "<C-y>", '<Esc>"+yyi', opts)
-- For nvim-cmp or other completion plugins
map("i", "<C-y>", "cmp.mapping.confirm({ select = true })", opts)
-- Motion & Navigation Screen Centering (zz)
map("n", "j", "jzz", opts)
map("n", "k", "kzz", opts)
map({ "n", "v" }, "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
map({ "n", "v" }, "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })
map({ "n", "v" }, "<C-f>", "<C-f>zz", { desc = "Page down and center" })
map({ "n", "v" }, "<C-b>", "<C-b>zz", { desc = "Page up and center" })
map({ "n", "v" }, "}", "}zz", { desc = "Next paragraph and center" })
map({ "n", "v" }, "{", "{zz", { desc = "Prev paragraph and center" })
map({ "n", "v" }, "G", "Gzz", { desc = "End of buffer and center" })
map({ "n", "v" }, "gg", "ggzz", { desc = "Start of buffer and center" })
map({ "n", "v" }, "%", "%zz", { desc = "Matching bracket and center" })

-- Search Centering (keep cursor centered during search navigation)
map("n", "n", "nzzzv", { desc = "Next search match and center" })
map("n", "N", "Nzzzv", { desc = "Prev search match and center" })
map("n", "*", "*zzzv", { desc = "Search word forward and center" })
map("n", "#", "#zzzv", { desc = "Search word backward and center" })
map("n", "g*", "g*zzzv", { desc = "Search word forward and center" })
map("n", "g#", "g#zzzv", { desc = "Search word backward and center" })

-- Jump List & Change List Centering
map("n", "<C-o>", "<C-o>zz", { desc = "Jump back and center" })
map("n", "<C-i>", "<C-i>zz", { desc = "Jump forward and center" })
map("n", "g;", "g;zz", { desc = "Prev change and center" })
map("n", "g,", "g,zz", { desc = "Next change and center" })

-- Paste & Visual Paste
map("n", "p", "pzz", { desc = "Paste and center" })
map("n", "P", "Pzz", { desc = "Paste before and center" })
map("x", "p", [["_dP]], { desc = "Paste without overwriting register" })

-- Map 'jk' to escape terminal mode
map("t", "jk", [[<C-\><C-n>]], { noremap = true, silent = true })
-- Custom mappings
map("n", "<leader>fm", function()
    require("yazi").yazi()
end, { desc = "Open Yazi file manager" })
map("n", "<leader>ts", ":Telescope colorscheme<CR>", opts)
map("n", "<leader>e", ":NvimTreeToggle<CR>", opts)
map("n", "<A-d>", ":NvimTreeClose<CR>", opts)
-- map("n", "<S-j>", ":bnext<CR>", opts)
-- map("n", "<S-k>", ":bprevious<CR>", opts)

map("n", "<S-k>", ":lua require('nvchad.tabufline').prev()<CR>", { noremap = true, silent = true })
map("n", "<S-j>", ":lua require('nvchad.tabufline').next()<CR>", { noremap = true, silent = true })
-- map("n", "<S-j>", require("nvchad.tabufline").prev())
-- map("n", "<S-k>", require("nvchad.tabufline").next())
map("n", "<leader>j", "J")
map("v", "<", "<gv", opts)
map("v", ">", ">gv", opts)
map("v", "J", ":m .+1<CR>==zz", opts)
map("v", "K", ":m .-2<CR>==zz", opts)
map("x", "J", ":move '>+1<CR>gv-gv", opts)
map("x", "K", ":move '<-2<CR>gv-gv", opts)
-- map("n", "<S-l>", vim.lsp.buf.hover, { desc = "Show hover information" })
-- map("n", "<S-l>", vim.lsp.buf.signature_help, { desc = "Show hover information" })
-- -- Remove default mappings
-- local nomap = vim.keymap.del
-- -- removed htoggleTerm
-- nomap("n", "<leader>h")
-- -- removed vtoggleTerm
-- nomap("n", "<leader>v")
-- nomap("n", "<leader>b")
-- nomap("n", "<leader>x")
-- nomap("n", "<C-n>")
-- nomap("n", "<space>wk")
-- nomap("n", "<space>n")
-- nomap("n", "<space>wK")
-- nomap("n", "<Tab>")
-- nomap("n", "<S-Tab>")
-- nomap("n", "<A-v>")
-- nomap("n", "<A-i>")
-- nomap("t", "<C-x>")
-- nomap("n", "<leader>rn")
-- nomap("n", "<M-i>")
-- nomap("n", "<M-v>")
--
--
--
-- Function to safely remove a keymap if it exists
local function safe_remove_keymap(mode, key)
    if vim.fn.maparg(key, mode) ~= "" then
        pcall(vim.keymap.del, mode, key) -- Use pcall to handle potential errors gracefully
    end
end

-- Remove default mappings
safe_remove_keymap("n", "<leader>h")
safe_remove_keymap("n", "<leader>v")
safe_remove_keymap("n", "<leader>b")
safe_remove_keymap("n", "<leader>x")
safe_remove_keymap("n", "<leader>th")
safe_remove_keymap("n", "<C-n>")
safe_remove_keymap("n", "<space>wk")
safe_remove_keymap("n", "<space>n")
safe_remove_keymap("n", "<space>wK")
safe_remove_keymap("n", "<Tab>")
safe_remove_keymap("n", "<S-Tab>")
safe_remove_keymap("n", "<A-v>")
safe_remove_keymap("n", "<A-i>")
safe_remove_keymap("t", "<C-x>")
safe_remove_keymap("n", "<leader>rn")
safe_remove_keymap("n", "<leader>ra") -- Safely handle non-existent mappings
-- safe_remove_keymap("n", "<M-i>")
-- safe_remove_keymap("n", "<M-v>")
map("n", "<S-Right>", ":vertical resize +5<CR>", opts)
map("n", "<S-Left>", ":vertical resize -5<CR>", opts)
map("n", "<S-Down>", ":resize +5<CR>", opts)
map("n", "<S-Up>", ":resize -5<CR>", opts)

-- Map `cr` to invoke the LSP renamer from NvChad
map("n", "cr", function()
    require("nvchad.lsp.renamer")() -- Assuming this is how the function is accessed
end, opts)
-- Remove the original mapping for <Space>ra in normal mode
--
map("n", "<leader>th", function()
    require("nvchad.themes").open({
        border = true,
        -- style = "compact",
        -- flat/compact
    })
end, opts)

map("n", "<leader>q", function()
    require("nvchad.tabufline").close_buffer()
end, opts)

map("n", "<leader>fh", ":Telescope oldfiles<CR>", { noremap = true, silent = true, desc = "Search Previous Files" })
-- Keybinding to resume the last Telescope search
map(
    "n",
    "<leader>fr",
    ":Telescope resume<CR>",
    { noremap = true, silent = true, desc = "Resume Last Telescope Search" }
)
map({ "n", "t" }, "<A-;>", function()
    require("nvchad.term").toggle({ pos = "sp", id = "htoggleTerm" })
end, { desc = "Toggle terminal horizontally" })

map("n", "<A-v>", ":vsplit<CR>", { noremap = true, silent = true, desc = "Vertical split" })

-- Horizontal split with Alt + h
map("n", "<A-h>", ":split<CR>", { noremap = true, silent = true, desc = "Horizontal split" })

-- Close current split with Alt + w
map("n", "<A-w>", ":close<CR>", { noremap = true, silent = true, desc = "Close current split" })

map("n", "<leader>sk", function()
    require("telescope.builtin").keymaps()
end, { desc = "Telescope Keymaps" })

map("n", "<leader>bb", ":lua InputCommand()<CR>", opts)

map("n", "<leader>j", "mzJ`z", { noremap = true, silent = true })
function InputCommand()
    local command = vim.fn.input("Shell command: ")
    vim.cmd("!" .. command)
end

map({ "n", "t" }, "<A-i>", function()
    require("nvchad.term").toggle({ pos = "float", id = "floatTerm" })
end, { desc = "terminal toggle floating term" })

--
--
-- Yank to system clipboard for any 'y' and '<Leader>d' mappings
map("v", "y", '"+y', opts) -- Visual mode yank to clipboard
map("n", "yy", '"+yy', opts) -- Normal mode double 'yy' to clipboard
map("n", "p", '"+p', opts) -- Paste from system clipboard
-- map("v", "<leader>y", '"+y', opts) -- Yank with <Leader> to clipboard
map("v", "p", '"+p', opts) -- Paste from clipboard in visual mode

-- Special handling for paste operations with specific behavior
map("n", "gp", 'o<Esc>"+p', opts) -- Paste in new line after cursor
map("n", "gP", 'O<Esc>"+P', opts) -- Paste in new line before cursor

-- Prevent content from being placed in clipboard when deleting, use black hole register
map("n", "d", '"_d', opts) -- Delete in normal mode without affecting clipboard
map("n", "dd", '"_dd', opts) -- Delete whole line without clipboard
map("v", "d", '"_d', opts) -- Delete in visual mode without clipboard
map("v", "D", '"_D', opts) -- Delete to the end of line without clipboard

-- Map <Leader>d to yank to system clipboard
map("n", "<Leader>d", '"+y', opts) -- Leader+d for system clipboard
map("v", "<Leader>d", '"+y', opts) -- Leader+d for system clipboard in visual mode

-- Replace paste with black hole register (paste the last delete)
map("v", "p", '"_dP', opts) -- Replace paste with black hole register

-- Select all content in normal mode
map("n", "<leader>sa", "ggVG", opts) -- Select all

-- Delete all content and store in black hole register
map("n", "<leader>da", 'ggVG"_d', opts) -- Delete all and store in black hole register

-- Yank all content to system clipboard
map("n", "<leader>ya", 'ggVG"+y', opts) -- Yank all to system clipboard

-- Source the current file using <leader>sf
map("n", "<leader>sf", ":source %<CR>", opts)

-- Create a new line below and return to normal mode
map("n", "<leader>n", "o<Esc>", opts)

-- Create a new line above and return to normal mode
map("n", "<leader>N", "O<Esc>", opts)

-- Map 'n' to search forward and center the result on the screen
map("n", "n", "nzz", opts)

-- Map 'N' to search backward and center the result on the screen
map("n", "N", "Nzz", opts)
-- map("n", "b", "ggVG", opts)
-- vim.cmd("highlight Search ctermbg=235 ctermfg=214 guibg=#dcdcdc guifg=#e1c16e")

-- Harpoon
---- Add the current file to Harpoon
-- map("n", "<leader>ha", require("harpoon.mark").add_file, { desc = "Add file to Harpoon" })
--
-- -- Toggle the Harpoon quick menu
-- map("n", "<leader>hh", require("harpoon.ui").toggle_quick_menu, { desc = "Toggle Harpoon menu" })
-- local harpoon_ui = require("harpoon.ui")
--
-- for i = 1, 9 do
--   map("n", "<leader>h" .. i, function()
--     harpoon_ui.nav_file(i)
--   end, { desc = "Navigate to Harpoon file " .. i })
-- end
-- map({ "n", "x" }, "<leader>sr", function()
-- 	require("ssr").open()
-- end)
--
-- Mapping leader tt to open a new tab
map("n", "<leader>tt", ":tabnew<CR>", opts)

-- Mapping Ctrl+m to paste from the system clipboard in insert mode
map("i", "<C-m>", "<C-R>+", opts)

map("n", "gg", "ggzz", opts)
map("n", "G", "Gzz", opts)

-- mapping with a lua function
-- map("n", "<A-i>", function()
--     -- do something
-- end, { desc = "Terminal toggle floating" })

--
map("n", "<Leader><Tab>", ":qa!<CR>", { noremap = true, silent = true, desc = "Force quit Neovim" })

-- Move focus between panes
map("n", "<C-h>", "<C-w>h", { desc = "Move focus to the left pane" })
map("n", "<C-j>", "<C-w>j", { desc = "Move focus to the bottom pane" })
map("n", "<C-k>", "<C-w>k", { desc = "Move focus to the top pane" })
map("n", "<C-l>", "<C-w>l", { desc = "Move focus to the right pane" })

-- Close the current tab with Ctrl+w
map("n", "<C-w>", ":tabclose<CR>", { desc = "Close current tab" })

-- Save current file with Leader+w
map("n", "<Leader>w", ":w<CR>", opts)

-- Save all files with Leader+W
map("n", "<Leader>W", ":wa<CR>", { desc = "Save all files in a buffer" })

-- Remove trailing semicolons and commas, and append semicolons and commas at the end
map("n", "<leader>d;", ":s/;$//<CR>", { noremap = true, silent = true, desc = "Remove trailing semicolons" })
map("n", "<leader>d,", ":s/,$//<CR>", { noremap = true, silent = true, desc = "Remove trailing commas" })
map("n", "<leader>;", "mzA;<Esc>`z", { noremap = true, silent = true, desc = "Append semicolon at the end" })
map("n", "<leader>,", "mzA,<Esc>`z", { noremap = true, silent = true, desc = "Append comma at the end" })

-- Map Ctrl+d to scroll down with centering
map("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })

-- Map Ctrl+u to scroll up with centering
map("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })

-- Yank to system clipboard in normal and visual mode
map("v", "y", '"+y', opts)
map("n", "yy", '"+yy', opts)
map("n", "p", '"+p', opts)
map("v", "<leader>y", '"+y', opts)
map("v", "p", '"+p', opts)

-- Paste from system clipboard with specific behavior
map("n", "gp", 'o<Esc>"+p', opts)
map("n", "gP", 'O<Esc>"+P', opts)
-- Prevent content from being placed in clipboard when deleting (use black hole register)
map("n", "d", '"_d', opts)
map("n", "dd", '"_dd', opts)
map("v", "d", '"_d', opts)
map("v", "D", '"_D', opts)
-- Map <Leader>d to yank to clipboard
map("n", "<Leader>d", '"+y', opts)
map("v", "<Leader>d", '"+y', opts)

-- Replace paste with black hole register
map("v", "p", '"_dP', opts)

-- Map [{ and ]} to center the screen after jumping
map("n", "[{", "{zz", { noremap = true, silent = true, desc = "Jump to previous block and center" })
map("n", "]}", "}zz", { noremap = true, silent = true, desc = "Jump to next block and center" })

-- Map <leader>ls to run :Lazy sync
-- map("n", "<leader>ls", ":Lazy sync<CR>", { noremap = true, silent = true, desc = "Sync lazy plugins" })

map("n", "<leader><leader>", ":lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>", opts)
-- Map Ctrl+; to toggle the terminal
---jtest
---

map("n", "<leader>rr", ":RunCode<CR>", { noremap = true, silent = false })
map("n", "<leader>rf", ":RunFile<CR>", { noremap = true, silent = false })
map("n", "<A-q>", ":RunFile<CR>", { noremap = true, silent = false })
map("n", "<leader>rft", ":RunFile tab<CR>", { noremap = true, silent = false })
map("n", "<leader>rp", ":RunProject<CR>", { noremap = true, silent = false })
map("n", "<leader>rc", ":RunClose<CR>", { noremap = true, silent = false })
map("n", "<leader>crf", ":CRFiletype<CR>", { noremap = true, silent = false })
map("n", "<leader>crp", ":CRProjects<CR>", { noremap = true, silent = false })

local builtin = require("telescope.builtin")

-- Set the keymap for searching Neovim configuration files
map("n", "<leader>oc", function()
    builtin.find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "[S]earch [N]eovim files Open Config " })

map("n", "<leader>ss", function()
    require("telescope.builtin").live_grep({
        grep_open_files = true,
        prompt_title = "Live Grep in Open Files",
    })
end, { desc = "[S]earch [/] in Open Files" })

-- Map <leader>cg to live grep within Neovim config directory
map(
    "n",
    "<leader>og",
    ':lua require("telescope.builtin").live_grep({ cwd = vim.fn.stdpath("config") })<CR>',
    { noremap = true, silent = true, desc = "[C]onfig [G]rep" }
)

-- map("n", "<Leader>fd", function()
-- 	require("conform").format({ async = true })
-- end, { noremap = true, silent = true })
-- Close all buffers except the current one
map("n", "<Leader>ct", ":lua require('nvchad.tabufline').closeAllBufs(false)<CR>", { noremap = true, silent = true })

-- Close all buffers to the right
map(
    "n",
    "<Leader>cr",
    ":lua require('nvchad.tabufline').closeBufs_at_direction('right')<CR>",
    { noremap = true, silent = true }
)
map(
    "n",
    "<Leader>cl",
    ":lua require('nvchad.tabufline').closeBufs_at_direction('left')<CR>",
    { noremap = true, silent = true }
)
-- Move the buffer to the left (using Alt + <)
--
-- Move buffer to the left (using Alt + Left Arrow)
map("n", "<A-Left>", ":lua require('nvchad.tabufline').move_buf(-1)<CR>", { noremap = true, silent = true })

-- Move buffer to the right (using Alt + Right Arrow)
map("n", "<A-Right>", ":lua require('nvchad.tabufline').move_buf(1)<CR>", { noremap = true, silent = true })

-- Map '+' to increment number (Ctrl+A)
map("n", "+", "<C-a>", { noremap = true, silent = true })

-- Map '-' to decrement number (Ctrl+X)
map("n", "-", "<C-x>", { noremap = true, silent = true })
map("n", "<leader>sh", ":lua print(vim.api.nvim_buf_get_name(0))<CR>", { noremap = true, silent = true })

map("n", "<leader>oe", function()
    local current_file = vim.fn.expand("%:p:h") -- Get the directory of the current file
    vim.cmd("silent !start explorer " .. current_file) -- Open Explorer at the directory
end, { noremap = true, silent = true, desc = "Open Explorer at current file location" })

local telescope = require("telescope.builtin")
local telescope_last = 0
function telescope_resume()
    if telescope_last == 0 then
        telescope_last = 1
        telescope.live_grep()
    else
        telescope.resume()
    end
end

map("n", "<leader>fd", telescope_resume, opts)
map("n", "<leader>ih", "<cmd>ToggleInlayHints<CR>", { desc = "Toggle inlay hints" })
-- Shortcut to use blackhole register by default
map("v", "c", '"_c', opts)
map("v", "C", '"_C', opts)
map("n", "c", '"_c', opts)
map("n", "C", '"_C', opts)
map("n", "x", '"_x')

map("n", "<leader>fk", function()
    print("hello world")
end)
