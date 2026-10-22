-- lua/plugins/faster.lua
-- Disables heavy UI features (treesitter, lsp, matchparen, illuminate, indent_blankline)
-- on big files (>2MB), long minified lines, and during fast macro execution.
return {
    "pteroctopus/faster.nvim",
    cmd = { "Faster" },
    event = { "BufReadPre", "BufNewFile" },
    opts = {
        behaviours = {
            bigfile = {
                on = true,
                filesize = 2,
                features_disabled = {
                    "illuminate",
                    "matchparen",
                    "lsp",
                    "treesitter",
                    "indent_blankline",
                    "vimopts",
                    "syntax",
                    "filetype",
                },
            },
            longline = {
                on = true,
                max_line_length = 1000,
                features_disabled = {
                    "illuminate",
                    "matchparen",
                    "lsp",
                    "treesitter",
                    "indent_blankline",
                    "vimopts",
                    "syntax",
                },
            },
            fastmacro = {
                on = true,
                features_disabled = {
                    "lualine",
                    "matchparen",
                },
            },
        },
    },
}
