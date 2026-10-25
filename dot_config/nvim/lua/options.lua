-- Load default NvChad options first
require("nvchad.options")

local o = vim.o
local fn = vim.fn

-- Basic editor behaviour
-- Statusline hidden by default; the renderer lives in lua/configs/statusline.lua
-- and <leader>us toggles it back on (laststatus = 3 shows one global bar).
-- The tabline is unaffected: it is controlled by 'showtabline', not 'laststatus'.
o.laststatus = 0
o.statusline = "%!v:lua.require'configs.statusline'.render()"
vim.opt.fillchars:append({
    stl = " ",
    stlnc = " ",
})
o.number = true
o.relativenumber = true
o.cursorline = true
o.termguicolors = true
o.background = "dark"
o.mouse = "a"

-- Search
o.ignorecase = true
o.smartcase = true
o.incsearch = true
o.hlsearch = true

-- Indentation defaults. Language overrides live in after/ftplugin.
o.expandtab = true
o.tabstop = 4
o.shiftwidth = 4
o.softtabstop = 4
o.smartindent = true
o.autoindent = true
o.textwidth = 0

-- Wrapping
o.wrap = true
o.linebreak = true
o.breakindent = true

-- Responsiveness and IDE feedback
o.updatetime = 250
o.timeoutlen = 300
o.scrolloff = 8
o.sidescrolloff = 8
o.signcolumn = "yes"
o.completeopt = "menu,menuone,noselect"
o.pumheight = 12
o.pumwidth = 30

-- Splits
o.splitright = true
o.splitbelow = true

-- Files and undo
o.swapfile = false
o.backup = false
o.writebackup = false
o.fixeol = true
local undodir = vim.fn.stdpath("state") .. "/undo"
if fn.isdirectory(undodir) == 0 then
    fn.mkdir(undodir, "p")
end
o.undofile = true
o.undodir = undodir

-- Sessions (excluding "blank" prevents empty ghost scratch buffers from being saved)
o.sessionoptions = "buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

-- Keep ShaDa disabled; undo history is separate and persistent.
o.shada = ""

-- Shell
if fn.executable("bash") == 1 then
    o.shell = "bash"
end

-- Folding via Treesitter. Folds start open; use za/zc/zo.
o.foldmethod = "expr"
o.foldexpr = "v:lua.vim.treesitter.foldexpr()"
o.foldlevel = 99
o.foldenable = false

-- Cursor
o.guicursor = "n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50"

-- Clipboard
o.clipboard = "unnamedplus"

-- Neovide tuning (harmless in terminal Neovim)
vim.g.neovide_animation_fps = 100
vim.g.neovide_scroll_animation_length = 0.3
vim.g.neovide_cursor_animation_length = 0.05
vim.g.neovide_cursor_trail_size = 0.5
-- Iosevka Nerd Font Mono matches ~/.config/foot/foot.ini
o.guifont = "Iosevka Nerd Font Mono:h22"
vim.opt.linespace = 10

-- Statusline highlights (theme-aware, refreshed on theme change)
require("configs.statusline").setup()
