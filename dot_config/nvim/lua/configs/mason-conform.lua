require("mason-conform").setup({
    ensure_installed = {
        "stylua",
        "ruff",
        "gofumpt",
        "goimports",
        "prettierd",
        "shfmt",
    },
    automatic_installation = false,
})
