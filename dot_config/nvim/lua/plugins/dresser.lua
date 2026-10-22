return {
    "stevearc/dressing.nvim",
    opts = {},

    cond = function()
        return not vim.g.vscode -- Exclude this plugin in VSCode
    end,
}
