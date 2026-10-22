pcall(function()
    dofile(vim.g.base46_cache .. "syntax")
    dofile(vim.g.base46_cache .. "treesitter")
end)

local ts = require("nvim-treesitter")

ts.setup({
    install_dir = vim.fn.stdpath("data") .. "/site",
})

local parsers = {
    "bash",
    "c",
    "cpp",
    "css",
    "dockerfile",
    "gitcommit",
    "gitignore",
    "go",
    "gomod",
    "gosum",
    "html",
    "java",
    "javascript",
    "json",
    "lua",
    "luadoc",
    "markdown",
    "markdown_inline",
    "printf",
    "python",
    "query",
    "regex",
    "rust",
    "scss",
    "toml",
    "tsx",
    "typescript",
    "vim",
    "vimdoc",
    "yaml",
}

-- Neovim maps javascriptreact to the plain "javascript" parser, which cannot
-- parse JSX. Point it at tsx so highlighting and tag-aware plugins
-- (nvim-ts-autotag) actually see the JSX nodes.
vim.treesitter.language.register("tsx", "javascriptreact")

-- Ensure desired parsers are installed asynchronously
ts.install(parsers)

-- Auto-start Treesitter highlighting for buffers
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("TreesitterHighlight", { clear = true }),
    callback = function(args)
        pcall(vim.treesitter.start, args.buf)
    end,
})

-- Enable Treesitter indentation (exclude languages with rock-solid built-in cindent / smart indent like Java, C, C++)
vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("TreesitterIndent", { clear = true }),
    callback = function(args)
        local ft = vim.bo[args.buf].filetype
        if ft == "java" or ft == "c" or ft == "cpp" then
            vim.bo[args.buf].indentexpr = ""
            vim.bo[args.buf].cindent = true
            vim.bo[args.buf].smartindent = false
            return
        end
        pcall(function()
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end)
    end,
})
