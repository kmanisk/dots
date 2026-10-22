return {
    "goolord/alpha-nvim",
    -- alpha itself must be available before VimEnter so the start page can be
    -- driven by the session layer (auto-session's no_restore hook). Its own
    -- autostart is disabled in configs/dashboard.lua; otherwise it races the
    -- session restore and can paint over a restored layout.
    lazy = false,
    dependencies = {
        "nvim-tree/nvim-web-devicons",
    },
    config = function()
        require("configs.dashboard").setup()
    end,
}
