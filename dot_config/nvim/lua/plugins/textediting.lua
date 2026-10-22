-- Text editing extensions, kept deliberately narrow.
--
-- Everything here is lazy: nothing loads during startup, only when a real
-- buffer is opened. A dashboard-only session loads none of it.
--
--   mini.ai            better around/inside text objects
--   mini.move          move lines and selections
--   mini.align         align text on a character
--   mini.bracketed     [b ]b [q ]q [t ]t and friends
--   treesitter-textobj function/class/parameter text objects
--   dial               smarter increment/decrement
--   vim-repeat         make plugin actions repeatable with .
--   todo-comments      collect TODO/FIXME/HACK into a Telescope list

return {
    {
        "echasnovski/mini.nvim",
        branch = "stable",
        -- Load when a real buffer is opened, never at startup.
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            require("mini.ai").setup({ n_lines = 500 })

            -- Alt+h/j/k/l are already taken by splits and the file tree, so
            -- move uses the shifted variants instead.
            require("mini.move").setup({
                mappings = {
                    left = "<A-H>",
                    right = "<A-L>",
                    down = "<A-J>",
                    up = "<A-K>",
                    line_left = "<A-H>",
                    line_right = "<A-L>",
                    line_down = "<A-J>",
                    line_up = "<A-K>",
                },
            })

            require("mini.align").setup()

            -- [b ]b buffers, [q ]q quickfix, [t ]t treesitter nodes, [d ]d
            -- diagnostics, [h ]h git hunks are mapped by gitsigns already and
            -- mini.bracketed does not claim them.
            require("mini.bracketed").setup()

            -- mini.operators is deliberately not enabled: its default gs and
            -- gx prefixes collide with the existing sneak (g s) and open-URL
            -- (g x) mappings in lua/mappings.lua.
        end,
    },

    {
        -- Split a one-line argument/parameter list onto separate lines, the
        -- inverse of J. Treesitter drivers ship for c, cpp, go, js/ts(x), lua,
        -- python, rust, html; Java is not covered by the upstream defaults.
        "AckslD/nvim-trevJ.lua",
        keys = {
            {
                "<leader>cj",
                function()
                    require("trevj").format_at_cursor()
                end,
                desc = "Split arguments to lines",
            },
        },
        config = function()
            require("trevj").setup()
        end,
    },

    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        branch = "main",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            require("nvim-treesitter-textobjects").setup({
                select = { lookahead = true },
            })

            local select = require("nvim-treesitter-textobjects.select")

            local function map(capture, lhs, desc)
                vim.keymap.set({ "x", "o" }, lhs, function()
                    select.select_textobject(capture, "textobjects")
                end, { desc = desc, remap = false })
            end

            map("@function.outer", "af", "Function (outer)")
            map("@function.inner", "if", "Function (inner)")
            map("@class.outer", "ac", "Class (outer)")
            map("@class.inner", "ic", "Class (inner)")
            map("@parameter.outer", "aa", "Parameter (outer)")
            map("@parameter.inner", "ia", "Parameter (inner)")
        end,
    },

    {
        "monaqa/dial.nvim",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            -- dial ships augends but registers no default group, so nothing
            -- increments without this. Keep the list small and predictable.
            local augend = require("dial.augend")
            require("dial.config").augends:register_group({
                default = {
                    augend.integer.alias.decimal,
                    augend.integer.alias.hex,
                    augend.constant.alias.bool,
                    augend.date.alias["%Y-%m-%d"],
                    augend.date.alias["%Y/%m/%d"],
                },
            })

            -- dial.map functions return key strings, not callbacks, so they are
            -- installed directly as the right-hand side of the mapping.
            local map = require("dial.map")
            vim.keymap.set("n", "<C-a>", map.inc_normal(), { desc = "Increment" })
            vim.keymap.set("n", "<C-x>", map.dec_normal(), { desc = "Decrement" })
            vim.keymap.set("n", "g<C-a>", map.inc_gnormal(), { desc = "Increment (sequential)" })
            vim.keymap.set("n", "g<C-x>", map.dec_gnormal(), { desc = "Decrement (sequential)" })
            vim.keymap.set("v", "<C-a>", map.inc_visual() .. "gv", { desc = "Increment selection" })
            vim.keymap.set("v", "<C-x>", map.dec_visual() .. "gv", { desc = "Decrement selection" })
            vim.keymap.set("v", "g<C-a>", map.inc_gvisual() .. "gv", { desc = "Increment selection (sequential)" })
            vim.keymap.set("v", "g<C-x>", map.dec_gvisual() .. "gv", { desc = "Decrement selection (sequential)" })
        end,
    },

    {
        "tpope/vim-repeat",
        event = { "BufReadPost", "BufNewFile" },
    },

    {
        "folke/todo-comments.nvim",
        event = { "BufReadPost", "BufNewFile" },
        dependencies = { "nvim-lua/plenary.nvim" },
        keys = {
            { "<leader>st", "<cmd>TodoTelescope<CR>", desc = "Todo list" },
        },
        opts = {},
    },
}
