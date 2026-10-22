-- Git integration that is not already covered by gitsigns, lazygit or
-- Telescope. Kept to a single command-based plugin so nothing loads at
-- startup.
return {
    {
        -- Copy or open a permalink to the current line or visual selection on
        -- GitHub/GitLab/Codeberg, resolved from the repo's origin remote.
        "linrongbin16/gitlinker.nvim",
        cmd = "GitLink",
        keys = {
            { "<leader>gy", "<cmd>GitLink<cr>", mode = { "n", "v" }, desc = "Copy git permalink" },
            { "<leader>gY", "<cmd>GitLink!<cr>", mode = { "n", "v" }, desc = "Open git permalink" },
        },
        opts = {},
        cond = function()
            return not vim.g.vscode
        end,
    },
}
