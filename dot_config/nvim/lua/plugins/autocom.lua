return {
    "smolck/command-completion.nvim",
    event = "CmdlineEnter",
    cond = function()
        return not vim.g.vscode
    end,
    config = function()
        require("command-completion").setup({
            border = "single",
            max_col_num = 5,
            min_col_width = 20,
            use_matchfuzzy = true,
            highlight_selection = true,
            highlight_directories = true,
            tab_completion = true,
        })
    end,
}
