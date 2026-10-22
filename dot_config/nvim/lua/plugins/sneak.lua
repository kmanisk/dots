-- lua/plugins/sneak.lua
return {
    "justinmk/vim-sneak",
    event = { "BufReadPost", "BufNewFile" },
    cond = function()
        return not vim.g.vscode
    end,
    init = function()
        -- 1-character labels for direct jumping to targets (like EasyMotion / Leap)
        vim.g["sneak#label"] = 1

        -- Smart case sensitivity: case-insensitive unless uppercase letters are typed
        vim.g["sneak#use_ic_scs"] = 1

        -- Clever-s: pressing 's' or 'S' again repeats the search to next/prev match
        vim.g["sneak#s_next"] = 1

        -- Absolute direction: 's' always goes forward, 'S' always goes backward
        vim.g["sneak#absolute_dir"] = 1

        -- Prompt indicator
        vim.g["sneak#prompt"] = "Sneak: "
    end,
}
