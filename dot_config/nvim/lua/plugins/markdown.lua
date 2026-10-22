-- Markdown rendering. Replaces OXY2DEV/markview.nvim.
-- Keybinds mirror Zed: <leader>mp = preview, <leader>mv = preview to the side.
return {
    {
        "MeanderingProgrammer/render-markdown.nvim",
        ft = { "markdown", "codecompanion" },
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
        keys = {
            {
                "<leader>mp",
                function()
                    require("render-markdown").toggle()
                end,
                ft = "markdown",
                desc = "Markdown preview",
            },
            {
                "<leader>mv",
                function()
                    require("render-markdown").preview()
                end,
                ft = "markdown",
                desc = "Markdown preview to the side",
            },
        },
        ---@module 'render-markdown'
        ---@type render.md.UserConfig
        opts = {
            render_modes = { "n", "c", "t" },
            heading = {
                sign = false,
                width = "block",
                left_pad = 0,
                right_pad = 1,
            },
            code = {
                sign = false,
                width = "block",
                right_pad = 1,
                border = "thin",
            },
            bullet = {
                icons = { "●", "○", "◆", "◇" },
            },
            checkbox = {
                enabled = true,
            },
            pipe_table = {
                preset = "round",
            },
            link = {
                enabled = true,
            },
            win_options = {
                conceallevel = { rendered = 3 },
                concealcursor = { rendered = "" },
            },
            completions = {
                lsp = { enabled = true },
            },
        },
    },
}
