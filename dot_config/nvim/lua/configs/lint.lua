local lint = require("lint")

lint.linters_by_ft = {
    python = { "ruff" },
    sh = { "shellcheck" },
    yaml = { "yamllint" },
    markdown = { "markdownlint" },
}

vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
    group = vim.api.nvim_create_augroup("IdeLint", { clear = true }),
    callback = function()
        lint.try_lint()
    end,
    desc = "Run filetype linters",
})
