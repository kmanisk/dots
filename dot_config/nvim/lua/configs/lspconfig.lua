-- Language servers for the languages configured in Zed.
-- NvChad's defaults() has already registered capabilities and the lua_ls
-- bootstrap; this file supplies the project-wide server set and settings.

local nvchad = require("nvchad.configs.lspconfig")
local capabilities = nvchad.capabilities

vim.lsp.config("*", {
    capabilities = capabilities,
})

vim.lsp.config("lua_ls", {
    settings = {
        Lua = {
            runtime = {
                version = "LuaJIT",
                path = vim.split(package.path, ";"),
            },
            diagnostics = {
                globals = { "vim" },
                disable = { "missing-fields" },
            },
            workspace = {
                library = {
                    vim.fn.expand("$VIMRUNTIME/lua"),
                    vim.fn.stdpath("config"),
                    "${3rd}/luv/library",
                },
                maxPreload = 1000,
                preloadFileSize = 150,
                checkThirdParty = false,
                ignoreDir = {
                    ".git",
                    "node_modules",
                    "target",
                    "dist",
                    "build",
                },
            },
            telemetry = { enable = false },
            completion = { callSnippet = "Replace" },
        },
    },
})

vim.lsp.config("pyright", {
    settings = {
        python = {
            analysis = {
                typeCheckingMode = "basic",
                autoImportCompletions = true,
                autoSearchPaths = true,
                useLibraryCodeForTypes = true,
                diagnosticMode = "openFilesOnly",
            },
        },
    },
})

vim.lsp.config("vtsls", {
    settings = {
        typescript = {
            updateImportsOnFileMove = { enabled = "always" },
            suggest = { completeFunctionCalls = true },
            preferences = { includePackageJsonAutoImports = "auto" },
        },
        javascript = {
            updateImportsOnFileMove = { enabled = "always" },
            suggest = { completeFunctionCalls = true },
            preferences = { includePackageJsonAutoImports = "auto" },
        },
        vtsls = {
            autoUseWorkspaceTsdk = true,
            enableMoveToFileCodeAction = true,
        },
    },
})

vim.lsp.config("html", {
    settings = {
        html = {
            suggest = { html5 = true },
            format = { wrapLineLength = 0 },
        },
    },
})

vim.lsp.config("cssls", {
    settings = {
        css = { validate = true },
        scss = { validate = true },
        less = { validate = true },
    },
})

vim.lsp.config("jsonls", {
    settings = {
        json = { validate = { enable = true } },
    },
})

vim.lsp.config("emmet_language_server", {
    settings = {
        emmet = {
            showExpandedAbbreviation = "always",
            showAbbreviationAsSuggestion = true,
            showSuggestionsAsSnippets = true,
        },
    },
})

vim.lsp.config("tailwindcss", {
    settings = {
        tailwindCSS = {
            validate = true,
            emmetCompletions = true,
            includeLanguages = {
                html = "html",
                javascript = "javascriptreact",
                javascriptreact = "javascriptreact",
                typescript = "typescriptreact",
                typescriptreact = "typescriptreact",
                vue = "vue",
                svelte = "svelte",
            },
        },
        editor = {
            quickSuggestions = { strings = true },
        },
    },
})

vim.lsp.config("rust_analyzer", {
    settings = {
        ["rust-analyzer"] = {
            cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
            },
            check = { command = "clippy" },
            procMacro = { enable = true },
            imports = {
                granularity = { group = "module" },
                prefix = "self",
            },
        },
    },
})

vim.lsp.config("gopls", {
    settings = {
        gopls = {
            gofumpt = true,
            usePlaceholders = true,
            completeUnimported = true,
            analyses = { unusedparams = true },
        },
    },
})

vim.lsp.config("clangd", {
    cmd = { "clangd", "--background-index", "--header-insertion=iwyu" },
})

vim.lsp.config("eslint", {
    settings = {
        workingDirectory = { mode = "location" },
    },
})

-- jdtls is registered and enabled by nvim-java (configs/java.lua). These
-- settings only cut background work: code lenses are never rendered in this UI
-- and completion payloads stay small.
vim.lsp.config("jdtls", {
    settings = {
        java = {
            referencesCodeLens = { enabled = false },
            implementationsCodeLens = { enabled = false },
            completion = { maxResults = 60 },
        },
    },
})

vim.lsp.config("bashls", {})
vim.lsp.config("yamlls", {
    settings = {
        yaml = {
            validate = true,
            hover = true,
            completion = true,
        },
    },
})
vim.lsp.config("marksman", {})

local servers = {
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
    "clangd",
    "eslint",
    "bashls",
    "yamlls",
    "marksman",
}

for _, server in ipairs(servers) do
    vim.lsp.enable(server)
end

-- NvChad's defaults() attaches through an LspAttach autocmd. Register the IDE
-- attach handler afterwards so it wins over NvChad's legacy workspace maps.
vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("IdeLspAttach", { clear = true }),
    callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        require("configs.ide").on_attach(client, args.buf)
    end,
    desc = "Attach IDE LSP keymaps",
})
