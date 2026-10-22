-- AI layer: CodeCompanion as a persistent right-hand sidebar (Zed agent panel analogue).
-- Fully lazy: nothing loads at startup, only on <leader>ia / <leader>ic / <leader>iA
-- or an explicit :CodeCompanion* command.
local function toggle_sidebar()
    local key = vim.env.GEMINI_API_KEY
    if key == nil or key == "" then
        vim.notify(
            "GEMINI_API_KEY is not set. Export it (or add it via chezmoi age) before chatting.",
            vim.log.levels.WARN,
            { title = "CodeCompanion" }
        )
    end
    vim.cmd("CodeCompanionChat Toggle")
end

return {
    "olimorris/codecompanion.nvim",
    cmd = { "CodeCompanion", "CodeCompanionChat", "CodeCompanionActions" },
    keys = {
        { "<leader>ia", "<cmd>CodeCompanion<CR>", mode = { "n", "v" }, desc = "Inline AI assist" },
        { "<leader>ic", toggle_sidebar, desc = "Toggle AI sidebar" },
        { "<leader>iA", "<cmd>CodeCompanionActions<CR>", mode = { "n", "v" }, desc = "AI actions" },
    },
    dependencies = {
        "nvim-lua/plenary.nvim",
        "MunifTanjim/nui.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
    cond = function()
        return not vim.g.vscode
    end,
    opts = {
        interactions = {
            chat = { adapter = "gemini", model = "gemini-3.5-flash" },
            inline = { adapter = "gemini", model = "gemini-3.5-flash" },
        },
        display = {
            chat = {
                window = {
                    layout = "vertical",
                    position = "right",
                    width = 0.42,
                    full_height = true,
                    sticky = true,
                    buflisted = false,
                    opts = {
                        breakindent = true,
                        linebreak = true,
                        wrap = true,
                    },
                },
            },
        },
    },
}
