-- Set cache and leader keys
vim.g.base46_cache = vim.fn.stdpath("data") .. "/base46/"
vim.g.mapleader = " "
vim.g.maplocalleader = " " -- Set local leader key

-- VSCode-specific setup
if vim.g.vscode then
    local vscode_plugins = require("user.vsplug")
    require("lazy").setup(vscode_plugins)
    require("user.vscode_keymaps")
else
    -- Bootstrap lazy and all plugins
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not vim.uv.fs_stat(lazypath) then
        local repo = "https://github.com/folke/lazy.nvim.git"
        vim.fn.system({ "git", "clone", "--filter=blob:none", repo, "--branch=stable", lazypath })
    end

    vim.opt.rtp:prepend(lazypath)

    local lazy_config = require("configs.lazy")
    require("lazy").setup({
        {
            "NvChad/NvChad",
            lazy = false,
            branch = "v2.5",
            import = "nvchad.plugins",
        },

        { import = "plugins" },

        {
            "nvim-lua/plenary.nvim",
            lazy = false,
        },
        {
            "L3MON4D3/LuaSnip",
            build = "make install_jsregexp",
            lazy = false,
        },
    }, lazy_config)

    -- Load theme (auto-recompile base46 if system theme changed, else instant dofile)
    local current_sys_theme = "gruvchad"
    local state_f = io.open(vim.fn.expand("~/.local/state/theme/name"), "r")
    if state_f then
        local t = state_f:read("*l")
        state_f:close()
        if t and t ~= "" then
            current_sys_theme = vim.trim(t)
        end
    end

    local cache_theme_f = io.open(vim.g.base46_cache .. "current_theme", "r")
    local cached_theme = nil
    if cache_theme_f then
        local ct = cache_theme_f:read("*l")
        cache_theme_f:close()
        if ct and ct ~= "" then
            cached_theme = vim.trim(ct)
        end
    end

    if cached_theme ~= current_sys_theme then
        pcall(function()
            require("nvconfig").base46.theme = current_sys_theme
            require("base46").load_all_highlights()
            local wf = io.open(vim.g.base46_cache .. "current_theme", "w")
            if wf then
                wf:write(current_sys_theme .. "\n")
                wf:close()
            end
        end)
    else
        pcall(dofile, vim.g.base46_cache .. "defaults")
        pcall(dofile, vim.g.base46_cache .. "statusline")
    end
    -- Ordinary Neovim setup
    require("options")
    --require("test")
    require("cusmap")
    -- require("plugins.themes.vscode")
    -- require("plugins.themes.bambo")
    -- ------------------------------
    -- Neovide font setup (Iosevka Nerd Font)
    -- ------------------------------
    if vim.g.neovide then
        -- Font name + size + ligatures
        vim.opt.guifont = "Iosevka NF:h14"
    end
    -- ------------------------------
    -- Load mappings after everything else
    vim.schedule(function()
        require("mappings")
    end)

    -- Automatically require all Lua files in pluginconfig directory
    local plugin_config_dir = vim.fn.stdpath("config") .. "/lua/plugconfig"
    if vim.fn.isdirectory(plugin_config_dir) == 1 then
        for _, file in ipairs(vim.fn.readdir(plugin_config_dir)) do
            if file:match(".+%.lua$") then
                require("plugconfig." .. file:match("^(.*)%.lua$"))
            end
        end
    end

    -- Autocmds and further Lua files sourcing
    require("nvchad.autocmds")

    -- Automatically source mappings.lua when saved
    vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = "lua/mappings.lua", -- Trigger only for mappings.lua
        callback = function()
            local mappings_path = vim.fn.stdpath("config") .. "/lua/mappings.lua"
            if vim.fn.filereadable(mappings_path) == 1 then
                vim.cmd("source " .. mappings_path)
                -- print("Reloaded mappings.lua")
            else
                -- print("Error: mappings.lua not found")
            end
        end,
        desc = "Automatically source mappings.lua on save",
    })
end
-- added by me
