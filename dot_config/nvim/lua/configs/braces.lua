-- Expand empty block bodies that formatters collapse onto a single line.
--
-- Some formatters have no option to keep an empty body on two lines:
-- prettier always prints empty function/class/arrow bodies as "{}", rustfmt
-- collapses empty structs and traits, stylua collapses empty Lua functions and
-- clang-format collapses empty Java class bodies. This pass normalises those
-- collapsed lines after formatting so an empty body always opens on its own
-- line and closes on the next one.
local M = {}

local filetypes = {
    c = true,
    cpp = true,
    go = true,
    java = true,
    javascript = true,
    javascriptreact = true,
    lua = true,
    rust = true,
    typescript = true,
    typescriptreact = true,
}

-- Words that introduce a block rather than an expression. Matched as whole
-- words, so identifiers such as "classification" never trigger.
local keywords = {
    "class",
    "struct",
    "interface",
    "enum",
    "record",
    "namespace",
    "union",
    "trait",
    "impl",
    "module",
    "try",
    "catch",
    "finally",
    "else",
    "do",
    "static",
    "if",
    "for",
    "while",
    "switch",
    "select",
    "func",
    "function",
}

local function is_comment(trimmed)
    return trimmed:match("^//") or trimmed:match("^#") or trimmed:match("^%*") or trimmed:match("^%-%-")
end

local function has_keyword(prefix)
    for _, keyword in ipairs(keywords) do
        if prefix:find("%f[%w_]" .. keyword .. "%f[^%w_]") then
            return true
        end
    end
    return false
end

local function expand_line(line)
    local indent = line:match("^(%s*)") or ""
    local trimmed = line:match("^%s*(.-)%s*$")
    if trimmed == "" or is_comment(trimmed) then
        return nil
    end

    -- Lua: stylua turns "function f()\nend" into "function f() end".
    if trimmed:match("^local%s+function%f[%W]") or trimmed:match("^function%f[%W]") then
        if trimmed:match("%b()%s*end$") then
            local prefix = trimmed:gsub("%s*end$", "")
            return { indent .. prefix, indent .. "end" }
        end
    end

    -- Braces: a line ending in "{}", optionally followed by a semicolon.
    local suffix = ""
    local body = trimmed
    if body:sub(-1) == ";" then
        suffix = ";"
        body = body:sub(1, -2):gsub("%s+$", "")
    end
    if body:sub(-2) ~= "{}" then
        return nil
    end

    local prefix = body:sub(1, -3):gsub("%s+$", "")
    if prefix == "" then
        return nil
    end
    if not (prefix:match("%)$") or prefix:match("=>$") or has_keyword(prefix)) then
        return nil
    end

    return { indent .. prefix .. " {", indent .. "}" .. suffix }
end

---@param bufnr integer
---@return boolean changed
function M.expand(bufnr)
    if bufnr == nil or bufnr == 0 then
        bufnr = vim.api.nvim_get_current_buf()
    end
    if not vim.api.nvim_buf_is_valid(bufnr) or not filetypes[vim.bo[bufnr].filetype] then
        return false
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local out = {}
    local changed = false
    for _, line in ipairs(lines) do
        local replacement = expand_line(line)
        if replacement then
            out[#out + 1] = replacement[1]
            out[#out + 1] = replacement[2]
            changed = true
        else
            out[#out + 1] = line
        end
    end

    if not changed then
        return false
    end
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, out)
    return true
end

return M
