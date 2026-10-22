local M = {}
package.loaded["configs.conform"] = M

local options = {
    formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_organize_imports", "ruff_format" },
        go = { "gofumpt", "goimports" },
        rust = { "rustfmt" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        java = { "clang-format" },
        javascript = { "prettierd", "prettier", stop_after_first = true },
        javascriptreact = { "prettierd", "prettier", stop_after_first = true },
        typescript = { "prettierd", "prettier", stop_after_first = true },
        typescriptreact = { "prettierd", "prettier", stop_after_first = true },
        html = { "prettierd", "prettier", stop_after_first = true },
        css = { "prettierd", "prettier", stop_after_first = true },
        scss = { "prettierd", "prettier", stop_after_first = true },
        less = { "prettierd", "prettier", stop_after_first = true },
        json = { "prettierd", "prettier", stop_after_first = true },
        jsonc = { "prettierd", "prettier", stop_after_first = true },
        yaml = { "prettierd", "prettier", stop_after_first = true },
        markdown = { "prettierd", "prettier", stop_after_first = true },
        mdx = { "prettierd", "prettier", stop_after_first = true },
        sh = { "shfmt" },
    },
    formatters = {
        shfmt = {
            prepend_args = { "-i", "4", "-ci" },
        },
        rustfmt = {
            prepend_args = { "--config", "empty_item_single_line=false,fn_single_line=false" },
        },
        ["clang-format"] = {
            -- google-java-format always collapses empty bodies to "{}" and has
            -- no option to keep them expanded, so Java uses clang-format with a
            -- dedicated style instead. C and C++ keep the existing style.
            prepend_args = function(_, ctx)
                if vim.bo[ctx.buf].filetype == "java" then
                    return {
                        "-style={BasedOnStyle: LLVM, Language: Java, IndentWidth: 4, ContinuationIndentWidth: 8, ColumnLimit: 100, AllowShortFunctionsOnASingleLine: None, AllowShortBlocksOnASingleLine: Never, AllowShortIfStatementsOnASingleLine: Never, AllowShortLoopsOnASingleLine: false, AllowShortLambdasOnASingleLine: None, IndentCaseLabels: true, BreakBeforeBraces: Attach, SortIncludes: false}",
                    }
                end
                return {
                    "-style={BasedOnStyle: LLVM, AllowShortFunctionsOnASingleLine: None, AllowShortBlocksOnASingleLine: Never, AllowShortLambdasOnASingleLine: None, AllowShortRecordOnASingleLine: Never, AllowShortEnumsOnASingleLine: false, AllowShortIfStatementsOnASingleLine: Never, AllowShortLoopsOnASingleLine: false}",
                }
            end,
        },
        stylua = {
            prepend_args = { "--collapse-simple-statement", "Never" },
        },
    },
    default_format_opts = {
        lsp_format = "fallback",
    },
    notify_on_error = false,
}

for k, v in pairs(options) do
    M[k] = v
end

require("conform").setup(options)

-- ---------------------------------------------------------------------------
-- Cursor and view preservation
--
-- conform applies its diff with vim.lsp.util.apply_text_edits, which parks the
-- cursor on the last edited line when a file needs more than one edit. Save the
-- window view before formatting and put it back afterwards, so the cursor stays
-- where it was and the window does not scroll.
-- ---------------------------------------------------------------------------

---@param bufnr integer
---@return table|nil
local function snapshot(bufnr)
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_buf(win) ~= bufnr then
        return nil
    end
    return {
        win = win,
        view = vim.fn.winsaveview(),
        lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false),
    }
end

---@param bufnr integer
---@param snap table|nil
local function restore(bufnr, snap)
    if not snap or not vim.api.nvim_win_is_valid(snap.win) then
        return
    end
    if vim.api.nvim_win_get_buf(snap.win) ~= bufnr then
        return
    end
    local count = vim.api.nvim_buf_line_count(bufnr)
    if count == 0 then
        return
    end

    local view = vim.deepcopy(snap.view)
    view.lnum = math.min(math.max(1, snap.view.lnum), count)
    view.topline = math.min(math.max(1, snap.view.topline), count)

    local previous_line = snap.lines[snap.view.lnum]
    local line = vim.api.nvim_buf_get_lines(bufnr, view.lnum - 1, view.lnum, false)[1] or ""
    if previous_line and previous_line:match("^%s*$") and not line:match("^%s*$") then
        -- The blank line under the cursor was folded away by the formatter.
        -- Sit at the end of the previous non-blank line (usually the opening
        -- brace) instead of on the line that replaced it.
        local above = view.lnum - 1
        while above >= 1 do
            local candidate = vim.api.nvim_buf_get_lines(bufnr, above - 1, above, false)[1] or ""
            if not candidate:match("^%s*$") then
                view.lnum = above
                view.col = #candidate
                break
            end
            above = above - 1
        end
    else
        view.col = math.min(snap.view.col, #line)
    end
    pcall(vim.fn.winrestview, view)
end

---Format a buffer synchronously, expand collapsed empty bodies and keep the
---cursor where it was.
---@param bufnr? integer
---@param opts? table
function M.format(bufnr, opts)
    if bufnr == nil or bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
    end
    local snap = snapshot(bufnr)
    local format_opts = vim.tbl_extend("keep", opts or {}, {
        bufnr = bufnr,
        async = false,
        timeout_ms = 2000,
        lsp_format = "fallback",
    })
    require("conform").format(format_opts)
    require("configs.braces").expand(bufnr)
    restore(bufnr, snap)
end

vim.api.nvim_create_autocmd("BufWritePre", {
    group = vim.api.nvim_create_augroup("ConformFormatOnSave", { clear = true }),
    callback = function(args)
        local buf = args.buf
        if vim.bo[buf].buftype ~= "" then
            return
        end
        if vim.b[buf].disable_autoformat or vim.g.disable_autoformat then
            return
        end
        local mode = vim.api.nvim_get_mode().mode
        if mode:find("^i") or mode:find("^R") then
            return
        end
        M.format(buf)
    end,
    desc = "Format on save and keep the cursor position",
})

return M
