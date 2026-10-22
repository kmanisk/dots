-- Font scaling.
--
-- A terminal emulator owns glyph size: Neovim cannot enlarge its own text
-- inside a TUI. Under foot the per-window zoom (Ctrl+= / Ctrl+- / Ctrl+0) is
-- handled by foot itself, so those keys must NOT be mapped here or the zoom
-- never reaches foot. The window that is launched for Neovim already uses a
-- larger font via the Sway binding in config.d/40-keybindings.conf.
--
-- GUI clients (Neovide, Goneovim) can be scaled from inside, so the mappings
-- below only exist there.

local M = {}

local default_size = 28
local current_size = default_size
local font_name = "VictorMono Nerd Font"

local function is_gui()
    return vim.g.neovide ~= nil or vim.fn.has("gui_running") == 1
end

local function update_font()
    if not is_gui() then
        return
    end
    vim.o.guifont = string.format("%s:h%.1f", font_name, current_size)
    vim.opt.linespace = math.floor(current_size * 0.45)
end

function M.increase_font()
    current_size = current_size + 1
    update_font()
    vim.notify(string.format("Font size: %.1f", current_size), vim.log.levels.INFO, { title = "Font Scale" })
end

function M.decrease_font()
    current_size = math.max(6, current_size - 1)
    update_font()
    vim.notify(string.format("Font size: %.1f", current_size), vim.log.levels.INFO, { title = "Font Scale" })
end

function M.reset_font()
    current_size = default_size
    update_font()
    vim.notify(string.format("Font size reset: %.1f", current_size), vim.log.levels.INFO, { title = "Font Scale" })
end

function M.setup()
    update_font()

    if not is_gui() then
        return
    end

    vim.keymap.set({ "n", "v" }, "<C-=>", M.increase_font, { desc = "Increase Font Size" })
    vim.keymap.set({ "n", "v" }, "<C-+>", M.increase_font, { desc = "Increase Font Size" })
    vim.keymap.set({ "n", "v" }, "<C-->", M.decrease_font, { desc = "Decrease Font Size" })
    vim.keymap.set({ "n", "v" }, "<C-0>", M.reset_font, { desc = "Reset Font Size" })

    -- Zed-style aliases.
    vim.keymap.set({ "n", "v" }, "<A-U>", M.increase_font, { desc = "Increase Font Size" })
    vim.keymap.set({ "n", "v" }, "<A-Y>", M.decrease_font, { desc = "Decrease Font Size" })
end

return M
