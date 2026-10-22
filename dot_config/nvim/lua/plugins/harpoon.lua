local function harpoon_ui()
  return require("harpoon.ui")
end

local function harpoon_mark()
  return require("harpoon.mark")
end

local keys = {
  { "<leader>a", function() harpoon_ui().toggle_quick_menu() end, desc = "Harpoon menu" },
  { "<leader>ha", function() harpoon_mark().add_file() end, desc = "Add file to Harpoon" },
  { "<leader>hh", function() harpoon_ui().toggle_quick_menu() end, desc = "Toggle Harpoon menu" },
  { "<leader>hr", function() harpoon_mark().rm_file() end, desc = "Remove file from Harpoon" },
  { "<leader>hn", function() harpoon_ui().nav_next() end, desc = "Next Harpoon file" },
  { "<leader>hp", function() harpoon_ui().nav_prev() end, desc = "Previous Harpoon file" },
}

for i = 1, 9 do
  keys[#keys + 1] = {
    "<leader>" .. i,
    function() harpoon_ui().nav_file(i) end,
    desc = "Harpoon file " .. i,
  }
end

return {
  "ThePrimeagen/harpoon",
  keys = keys,
  cond = function()
    return not vim.g.vscode
  end,
  config = function()
    require("harpoon").setup({
      global_settings = {
        save_on_toggle = true,
        save_on_change = true,
        enter_on_sendcmd = false,
        excluded_filetypes = { "harpoon" },
      },
    })

    local map = vim.keymap.set
    local ui = require("harpoon.ui")
    local mark = require("harpoon.mark")

    map("n", "<leader>a", ui.toggle_quick_menu, { desc = "Harpoon menu" })
    map("n", "<leader>ha", mark.add_file, { desc = "Add file to Harpoon" })
    map("n", "<leader>hh", ui.toggle_quick_menu, { desc = "Toggle Harpoon menu" })
    -- harpoon renamed remove_file to rm_file; keep the mapping stable.
    map("n", "<leader>hr", mark.rm_file, { desc = "Remove file from Harpoon" })
    map("n", "<leader>hn", ui.nav_next, { desc = "Next Harpoon file" })
    map("n", "<leader>hp", ui.nav_prev, { desc = "Previous Harpoon file" })

    for i = 1, 9 do
      map("n", "<leader>" .. i, function()
        ui.nav_file(i)
      end, { desc = "Harpoon file " .. i })
    end
  end,
}
