require("mason-lspconfig").setup({
    ensure_installed = {
        "lua_ls",
        "pyright",
        "vtsls",
        "html",
        "cssls",
        "jsonls",
        "emmet_language_server",
        "tailwindcss",
        "rust_analyzer",
        "gopls",
        "eslint",
        "bashls",
        "yamlls",
        "marksman",
    },
    automatic_installation = false,
})
