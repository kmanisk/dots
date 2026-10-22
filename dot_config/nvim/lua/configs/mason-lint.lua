require("mason-nvim-lint").setup({
    ensure_installed = {
        "ruff",
        "yamllint",
        "markdownlint",
    },
    automatic_installation = false,
})
