-- NvChad <-> System Theme Sync
-- Synchronizes theme changes between NvChad and the system-wide theme engine.
-- Uses loop prevention via vim.g.system_theme_sync flag and augroup.

local group = vim.api.nvim_create_augroup("NvChadSystemThemeSync", { clear = true })

vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "NvThemeReload",
    callback = function()
        -- Loop prevention: if theme reload originated from system RPC, do not trigger theme-set
        if vim.g.system_theme_sync then
            return
        end

        local theme = vim.g.nvchad_theme
        if not theme or theme == "" then
            local ok, nvconfig = pcall(require, "nvconfig")
            if ok and nvconfig and nvconfig.base46 and nvconfig.base46.theme then
                theme = nvconfig.base46.theme
            end
        end

        if not theme or theme == "" then
            local ok, chadrc = pcall(require, "chadrc")
            if ok and chadrc and chadrc.base46 and chadrc.base46.theme then
                theme = chadrc.base46.theme
            end
        end

        -- Check current system theme from state file to avoid redundant trigger
        local state_theme = nil
        local state_file = vim.fn.expand("~/.local/state/theme/name")
        local f = io.open(state_file, "r")
        if f then
            local t = f:read("*l")
            f:close()
            if t then
                state_theme = vim.trim(t)
            end
        end

        if theme and theme ~= "" and theme ~= state_theme then
            vim.system({ vim.fn.expand("~/.local/bin/theme-set"), theme }, { text = true })
        end
    end,
    desc = "Synchronize NvChad theme changes to system",
})
