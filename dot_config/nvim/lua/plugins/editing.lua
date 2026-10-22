-- Editor gaps versus Zed: rainbow brackets and sticky scroll (treesitter context).
-- Both are lazy and only attach on real buffers.
return {
    {
        "HiPhish/rainbow-delimiters.nvim",
        event = { "BufReadPost", "BufNewFile" },
        main = "rainbow-delimiters.setup",
        opts = {
            strategy = {
                [""] = "rainbow-delimiters.strategy.global",
                vim = "rainbow-delimiters.strategy.local",
            },
            query = {
                [""] = "rainbow-delimiters",
                lua = "rainbow-blocks",
            },
            priority = {
                [""] = 110,
                lua = 210,
            },
        },
    },
    {
        "nvim-treesitter/nvim-treesitter-context",
        event = { "BufReadPost", "BufNewFile" },
        keys = {
            {
                "<leader>uC",
                function()
                    require("treesitter-context").toggle()
                end,
                desc = "Toggle sticky scroll",
            },
        },
        opts = {
            enable = true,
            max_lines = 3,
            min_window_height = 20,
            line_numbers = false,
            multiline_threshold = 1,
            trim_scope = "outer",
            mode = "cursor",
            separator = nil,
        },
    },
    {
        -- Per-file indentation detection instead of Neovim's guess, which
        -- gets confused by mixed Java (4 spaces), TS (2), Go (tabs) repos.
        "NMAC427/guess-indent.nvim",
        event = { "BufReadPost", "BufNewFile" },
        opts = {},
    },
    {
        -- camelCase / snake_case aware w, e, b, ge. Matches how Zed's word
        -- motions behave and stops mid-identifier in Java and TypeScript.
        -- String form (<cmd>lua) keeps dot-repeat working.
        "chrisgrieser/nvim-spider",
        event = { "BufReadPost", "BufNewFile" },
        config = function()
            require("spider").setup({
                skipInsignificantPunctuation = true,
                subwordMovement = true,
            })

            for _, motion in ipairs({ "w", "e", "b", "ge" }) do
                vim.keymap.set({ "n", "o", "x" }, motion, ("<cmd>lua require('spider').motion('%s')<CR>"):format(motion), {
                    desc = "Spider: " .. motion,
                })
            end
        end,
    },
    {
        -- Close and rename HTML / JSX tags. Parsers for html, javascript and
        -- tsx are already installed, so this adds no parser work.
        "windwp/nvim-ts-autotag",
        ft = { "html", "javascript", "javascriptreact", "typescriptreact" },
        opts = {},
    },
}
