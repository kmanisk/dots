-- Multi-cursor editing, matching Zed's vim-mode g l / g L / g a.
-- Lazy: loads on first keypress only.
return {
    "jake-stewart/multicursor.nvim",
    branch = "1.0",
    keys = {
        {
            "g l",
            function()
                require("multicursor-nvim").matchAddCursor(1)
            end,
            mode = { "n", "x" },
            desc = "Add cursor on next match",
        },
        {
            "g L",
            function()
                require("multicursor-nvim").matchAddCursor(-1)
            end,
            mode = { "n", "x" },
            desc = "Add cursor on previous match",
        },
        {
            "g a",
            function()
                require("multicursor-nvim").matchAllAddCursors()
            end,
            mode = { "n", "x" },
            desc = "Add cursors on all matches",
        },
    },
    config = function()
        local mc = require("multicursor-nvim")
        mc.setup()

        local set = vim.keymap.set

        -- Add a cursor above or below the main cursor.
        set({ "n", "x" }, "<Up>", function()
            mc.lineAddCursor(-1)
        end, { desc = "Add cursor above" })
        set({ "n", "x" }, "<Down>", function()
            mc.lineAddCursor(1)
        end, { desc = "Add cursor below" })

        -- Mouse cursors (Zed uses alt-click; ctrl-click survives terminal encoding).
        set("n", "<C-LeftMouse>", mc.handleMouse)
        set("n", "<C-LeftDrag>", mc.handleMouseDrag)
        set("n", "<C-LeftRelease>", mc.handleMouseRelease)

        mc.addKeymapLayer(function(layerSet)
            layerSet({ "n", "x" }, "<Left>", mc.prevCursor)
            layerSet({ "n", "x" }, "<Right>", mc.nextCursor)
            layerSet({ "n", "x" }, "<C-q>", mc.toggleCursor)
            layerSet("n", "<Esc>", function()
                if not mc.cursorsEnabled() then
                    mc.enableCursors()
                else
                    mc.clearCursors()
                end
            end)
        end)

        local hl = vim.api.nvim_set_hl
        hl(0, "MultiCursorCursor", { reverse = true })
        hl(0, "MultiCursorVisual", { link = "Visual" })
        hl(0, "MultiCursorSign", { link = "SignColumn" })
        hl(0, "MultiCursorMatchPreview", { link = "Search" })
        hl(0, "MultiCursorDisabledCursor", { reverse = true })
        hl(0, "MultiCursorDisabledVisual", { link = "Visual" })
        hl(0, "MultiCursorDisabledSign", { link = "SignColumn" })
    end,
}
