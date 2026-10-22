return {
    -- ---------------------------------------------------------------------
    -- Key discovery
    -- ---------------------------------------------------------------------
    {
        "folke/which-key.nvim",
        event = "VeryLazy",
        opts = function()
            dofile(vim.g.base46_cache .. "whichkey")
            return {
                preset = "classic",
                delay = 300,
                icons = {
                    breadcrumb = "",
                    separator = "->",
                    group = "+",
                    ellipsis = "...",
                },
                win = {
                    border = "single",
                    padding = { 1, 2 },
                },
                spec = {
                    { "<leader>R", group = "replace" },
                    { "<leader>p", group = "problems / lists" },
                    { "<leader>f", group = "find / format" },
                    { "<leader>o", group = "open" },
                    { "<leader>c", group = "code" },
                    { "<leader>g", group = "git / layout" },
                    { "<leader>h", group = "harpoon" },
                    { "<leader>r", group = "run" },
                    { "<leader>t", group = "terminal / theme" },
                    { "<leader>u", group = "ui" },
                    { "<leader>v", group = "view" },
                    { "<leader>z", group = "zen" },
                    { "<leader>i", group = "ai / inlay" },
                    { "<leader>m", group = "markdown" },
                    { "<leader>n", group = "new" },
                    { "<leader>d", group = "delete / close" },
                    { "<leader>D", group = "debug" },
                    { "<leader>s", group = "search / session" },
                    { "<leader>1", desc = "Harpoon 1" },
                    { "<leader>2", desc = "Harpoon 2" },
                    { "<leader>3", desc = "Harpoon 3" },
                    { "<leader>4", desc = "Harpoon 4" },
                    { "<leader>5", desc = "Harpoon 5" },
                    { "<leader>6", desc = "Harpoon 6" },
                    { "<leader>7", desc = "Harpoon 7" },
                    { "<leader>8", desc = "Harpoon 8" },
                    { "<leader>9", desc = "Harpoon 9" },
                    { "<leader>w", desc = "Save and format" },
                    { "<leader>W", desc = "Save without formatting" },
                    { "<leader>q", desc = "Close buffer" },
                    { "<leader>e", desc = "Project panel" },
                    { "<leader>x", desc = "Extensions / plugins" },
                },
            }
        end,
    },

    -- ---------------------------------------------------------------------
    -- Git hunks
    -- ---------------------------------------------------------------------
    {
        "lewis6991/gitsigns.nvim",
        event = { "BufReadPre", "BufNewFile" },
        opts = {
            signs = {
                add = { text = "+" },
                change = { text = "~" },
                delete = { text = "_" },
                topdelete = { text = "‾" },
                changedelete = { text = "~" },
                untracked = { text = "┆" },
            },
            signcolumn = true,
            numhl = false,
            linehl = false,
            word_diff = false,
            watch_gitdir = { follow_files = true },
            attach_to_untracked = true,
            current_line_blame = false,
            current_line_blame_opts = {
                delay = 500,
                virt_text_pos = "eol",
            },
            update_debounce = 100,
            max_file_length = 40000,
            preview_config = { border = "single" },
            on_attach = function(bufnr)
                local gs = package.loaded.gitsigns
                local function map(mode, lhs, rhs, desc)
                    vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
                end

                map("n", "]h", gs.next_hunk, "Next git hunk")
                map("n", "[h", gs.prev_hunk, "Previous git hunk")
                map("n", "<leader>ghd", gs.diffthis, "Diff hunk")
                map("n", "<leader>ghp", gs.preview_hunk, "Preview hunk")
                map("n", "<leader>ghs", gs.stage_hunk, "Stage hunk")
                map("n", "<leader>ghr", gs.reset_hunk, "Reset hunk")
                map("n", "<leader>ghu", gs.undo_stage_hunk, "Undo stage hunk")
                map("n", "<leader>ghb", function()
                    gs.blame_line({ full = true })
                end, "Blame line")
                map("n", "<leader>ght", gs.toggle_current_line_blame, "Toggle line blame")
                map("n", "<leader>ghR", gs.reset_buffer, "Reset buffer hunks")
                map("n", "<leader>ghS", gs.stage_buffer, "Stage buffer hunks")
            end,
        },
    },

    -- ---------------------------------------------------------------------
    -- Project tree (Full Lua-based file tree)
    -- ---------------------------------------------------------------------
    {
        "nvim-tree/nvim-tree.lua",
        opts = function(_, opts)
            opts = opts or {}
            opts.filters = vim.tbl_deep_extend("force", opts.filters or {}, { dotfiles = false })
            opts.git = { enable = true, ignore = false, timeout = 500 }
            opts.update_focused_file = { enable = true, update_root = false }
            opts.sync_root_with_cwd = true
            opts.disable_netrw = true
            opts.hijack_netrw = true
            opts.hijack_cursor = true
            opts.view = vim.tbl_deep_extend("force", opts.view or {}, {
                width = 24,
                side = "left",
                preserve_window_proportions = true,
            })
            opts.renderer = vim.tbl_deep_extend("force", opts.renderer or {}, {
                root_folder_label = false,
                highlight_git = true,
                indent_markers = { enable = true },
            })
            opts.on_attach = function(bufnr)
                local api = require("nvim-tree.api")
                api.config.mappings.default_on_attach(bufnr)

                -- nvim-tree ships three rename variants (e = basename,
                -- u = full path, <C-r> = omit filename) plus bare y and c
                -- mappings. Those bare keys fire immediately and swallow the
                -- yy / yf / yn and cp / cn sequences defined below.
                for _, lhs in ipairs({ "<C-r>", "u", "y" }) do
                    pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
                end
                vim.keymap.set("n", "e", "<Nop>", {
                    buffer = bufnr,
                    nowait = true,
                    desc = "nvim-tree: rename is r",
                })

                local function map(lhs, rhs, desc)
                    vim.keymap.set("n", lhs, rhs, {
                        buffer = bufnr,
                        noremap = true,
                        silent = true,
                        nowait = true,
                        desc = "nvim-tree: " .. desc,
                    })
                end

                map("l", api.node.open.edit, "Open file or directory")
                map("<CR>", api.node.open.edit, "Open file or directory")
                map("h", api.node.navigate.parent_close, "Collapse directory")
                map("za", api.node.open.edit, "Toggle directory")
                map("a", api.fs.create, "Create file or directory")
                map("A", api.fs.create, "Create file or directory")
                map("d", api.fs.remove, "Delete file or directory")
                map("r", api.fs.rename, "Rename file or directory")
                map("c", api.fs.copy.node, "Copy file")
                map("p", api.fs.paste, "Paste file")
                map("x", api.fs.cut, "Cut file")
                map("yy", api.fs.copy.filename, "Copy name")
                map("yf", api.fs.copy.absolute_path, "Copy absolute path")
                map("yn", api.fs.copy.relative_path, "Copy relative path")
                map("oe", api.node.run.system, "Reveal with system opener")
                map("R", api.tree.reload, "Refresh tree")
                map("q", api.tree.close, "Close file tree")
            end
            return opts
        end,
    },

    -- ---------------------------------------------------------------------
    -- Integrated Terminal (ToggleTerm parity with Zed's Alt+;)
    -- ---------------------------------------------------------------------
    {
        "akinsho/toggleterm.nvim",
        version = "*",
        cmd = { "ToggleTerm", "TermExec", "ToggleTermToggleAll" },
        keys = {
            { "<A-;>", "<cmd>ToggleTerm direction=horizontal<CR>", mode = { "n", "t", "i" }, desc = "Toggle integrated terminal" },
            { "<C-;>", "<cmd>ToggleTerm direction=horizontal<CR>", mode = { "n", "t", "i" }, desc = "Toggle integrated terminal" },
            { "<leader>tt", "<cmd>ToggleTerm direction=horizontal<CR>", desc = "Toggle terminal" },
            { "<leader>tf", "<cmd>ToggleTerm direction=float<CR>", desc = "Float terminal" },
            { "<leader>tv", "<cmd>ToggleTerm direction=vertical<CR>", desc = "Vertical terminal" },
            { "<leader>tT", "<cmd>ToggleTermToggleAll<CR>", desc = "Close all terminals" },
        },
        opts = {
            size = 8,
            direction = "horizontal",
            start_in_insert = true,
            close_on_exit = false,
            persist_size = true,
            shade_terminals = false,
            shell = vim.o.shell,
            winbar = { enabled = false },
            -- Terminal floats use a double border; every other float in the
            -- config uses a single one, so terminals read as their own thing.
            float_opts = {
                border = "double",
                winblend = 0,
            },
            on_open = function(term)
                local ok, ide = pcall(require, "configs.ide")
                if ok and ide.setup_terminal_buffer then
                    ide.setup_terminal_buffer(term.bufnr)
                end
            end,
        },
    },

    -- ---------------------------------------------------------------------
    -- Code action preview
    -- ---------------------------------------------------------------------
    -- <leader>ca is wired in configs/ide.lua on LspAttach; this only loads
    -- once a language server is actually running.
    {
        "aznhe21/actions-preview.nvim",
        event = "LspAttach",
        opts = {
            backend = { "telescope" },
        },
    },

    -- ---------------------------------------------------------------------
    -- Quickfix / location list
    -- ---------------------------------------------------------------------
    -- Editable quickfix buffer with context lines, replaces the raw :copen
    -- view used by grep results and <leader>ds.
    {
        "stevearc/quicker.nvim",
        keys = {
            {
                "<leader>pq",
                function()
                    require("quicker").toggle()
                end,
                desc = "Quickfix list",
            },
            {
                "<leader>pl",
                function()
                    require("quicker").toggle({ loclist = true })
                end,
                desc = "Location list",
            },
        },
        opts = {
            keys = {
                {
                    ">",
                    function()
                        require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
                    end,
                    desc = "Expand context",
                },
                {
                    "<",
                    function()
                        require("quicker").collapse()
                    end,
                    desc = "Collapse context",
                },
            },
        },
    },

    -- ---------------------------------------------------------------------
    -- Diagnostics / references panel
    -- ---------------------------------------------------------------------
    {
        "folke/trouble.nvim",
        cmd = "Trouble",
        opts = {
            focus = true,
            auto_close = true,
            win = { border = "single" },
        },
    },

    -- ---------------------------------------------------------------------
    -- Document outline
    -- ---------------------------------------------------------------------
    {
        "hedyhli/outline.nvim",
        cmd = { "Outline", "OutlineOpen" },
        opts = {
            outline_window = {
                position = "right",
                width = 30,
                auto_close = true,
            },
            outline_items = {
                show_symbol_details = true,
                auto_set_cursor = true,
            },
        },
    },
}
