-- Java indentation, new line formatting, and auto-skeleton for new files

vim.bo.expandtab = true
vim.bo.tabstop = 4
vim.bo.shiftwidth = 4
vim.bo.softtabstop = 4
vim.bo.autoindent = true
vim.bo.smartindent = false
vim.bo.cindent = true
vim.bo.indentexpr = ""

-- Java cindent formatting options for clean brace, loop, and method indentation
vim.opt_local.cinoptions = "j1,(0,ws,m1"

-- Do not automatically insert comment leader on 'o' or 'O', but preserve in comments
vim.opt_local.formatoptions:remove("o")
vim.opt_local.formatoptions:append("crql")

-- Auto-skeleton: when opening a new empty Java file, scaffold the class and main method
local bufnr = vim.api.nvim_get_current_buf()
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
if #lines <= 1 and (lines[1] == nil or lines[1] == "") then
    local filename = vim.fn.expand("%:t:r")
    if filename and filename ~= "" and filename:match("^[%a_][%w_]*$") then
        local template = {
            "public class " .. filename .. " {",
            "    public static void main(String[] args) {",
            "        ",
            "    }",
            "}",
        }
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, template)
        -- Position cursor inside main method (line 3, column 9)
        pcall(vim.api.nvim_win_set_cursor, 0, { 3, 8 })
    end
end
