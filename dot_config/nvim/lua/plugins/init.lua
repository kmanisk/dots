return {
    {
        "nvim-treesitter/nvim-treesitter",
        branch = "main",
        event = { "BufReadPost", "BufNewFile" },
        build = ":TSUpdate",
        config = function()
            require("configs.treesitter")
        end,
    },

    {
        "nvim-java/nvim-java",
        ft = { "java" },
        config = function()
            require("configs.java").setup()
        end,
    },

    {
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("nvchad.configs.lspconfig").defaults()
            require("configs.lspconfig")

            -- Enforce diagnostic severity filter: completely suppress warnings/hints/info inline & signs
            local x = vim.diagnostic.severity
            vim.diagnostic.config({
                virtual_text = {
                    severity = { min = x.ERROR },
                    spacing = 2,
                    prefix = ">>",
                    source = "if_many",
                },
                signs = {
                    severity = { min = x.ERROR },
                    text = { [x.ERROR] = "E" },
                },
                underline = {
                    severity = { min = x.ERROR },
                },
                update_in_insert = false,
                severity_sort = true,
                float = {
                    border = "single",
                    source = true,
                    header = "",
                    prefix = "",
                },
            })
        end,
    },

    {
        "williamboman/mason-lspconfig.nvim",
        event = "VeryLazy",
        dependencies = { "nvim-lspconfig" },
        config = function()
            require("configs.mason-lspconfig")
        end,
    },

    {
        "mfussenegger/nvim-lint",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("configs.lint")
        end,
    },

    {
        "rshkarin/mason-nvim-lint",
        event = "VeryLazy",
        dependencies = { "nvim-lint" },
        config = function()
            require("configs.mason-lint")
        end,
    },

    {
        "stevearc/conform.nvim",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("configs.conform")
        end,
    },

    {
        "zapling/mason-conform.nvim",
        event = "VeryLazy",
        dependencies = { "conform.nvim" },
        config = function()
            require("configs.mason-conform")
        end,
    },

    {
        "hrsh7th/nvim-cmp",
        cond = function()
            return not vim.g.vscode
        end,
        dependencies = {
            "hrsh7th/cmp-nvim-lsp",
            "hrsh7th/cmp-nvim-lsp-signature-help",
            "hrsh7th/cmp-nvim-lua",
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "L3MON4D3/LuaSnip",
            "saadparwaiz1/cmp_luasnip",
            "onsails/lspkind-nvim",
            "kyazdani42/nvim-web-devicons",
        },
        config = function()
            require("configs.cmp").setup()
        end,
    },
    {
        "NvChad/nvterm",
        enabled = false,
    },

    {
        "CRAG666/code_runner.nvim",
        cmd = { "RunCode", "RunFile", "RunProject", "RunClose" },
        cond = function()
            return not vim.g.vscode
        end,
        opts = {
            mode = "toggleterm",
            focus = true,
            startinsert = true,
            term = {
                position = "bot",
                size = 8,
            },
            filetype = {
                java = {
                    "cd $dir &&",
                    "javac $fileName &&",
                    "java $fileNameWithoutExt",
                },
                python = "python3 -u",
                c = "cd $dir && gcc $fileName -o /tmp/$fileNameWithoutExt && /tmp/$fileNameWithoutExt",
                cpp = "cd $dir && g++ $fileName -o /tmp/$fileNameWithoutExt && /tmp/$fileNameWithoutExt",
                rust = {
                    "cd $dir &&",
                    "rustc $fileName -o /tmp/$fileNameWithoutExt &&",
                    "/tmp/$fileNameWithoutExt",
                },
                go = "go run",
                javascript = "node",
                typescript = "deno run",
                sh = "bash",
            },
        },
    },

    {
        "Mofiqul/vscode.nvim",
        cond = function()
            return not vim.g.vscode
        end,
    },
    {
        "wellle/targets.vim",
        event = { "BufReadPost", "BufNewFile" },
        cond = function()
            return not vim.g.vscode
        end,
    },
    {
        "kdheepak/lazygit.nvim",
        lazy = true,
        cmd = {
            "LazyGit",
            "LazyGitConfig",
            "LazyGitCurrentFile",
            "LazyGitFilter",
            "LazyGitFilterCurrentFile",
        },
        dependencies = {
            "nvim-lua/plenary.nvim",
        },
        keys = {
            { "<leader>lg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
        },
        config = function()
            vim.g.lazygit_floating_window_winblend = 0
            vim.g.lazygit_floating_window_scaling_factor = 0.9
            vim.g.lazygit_floating_window_border_chars = { "╭", "─", "╮", "│", "╯", "─", "╰", "│" }
            vim.g.lazygit_floating_window_use_plenary = 0
            vim.g.lazygit_use_neovim_remote = 1
            vim.g.lazygit_use_custom_config_file_path = 0
            vim.g.lazygit_config_file_path = {}
            vim.g.lazygit_on_exit_callback = nil
        end,
    },

}
