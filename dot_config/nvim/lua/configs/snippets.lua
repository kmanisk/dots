-- Snippet set, kept small and deliberate.
--
-- Two groups per language:
--   1. common actions (function, if, for, print, entry point) defined first
--   2. collection helpers (list, map, set, stream)
--
-- cmp ranks the "luasnip" source above nvim_lsp, so these appear at the top
-- of the completion menu in every filetype (see lua/configs/cmp.lua).

local ls = require("luasnip")
local s = ls.snippet
local i = ls.insert_node
local t = ls.text_node
local fmt = require("luasnip.extras.fmt").fmt

local M = {}

-- Rank the curated snippets above the VSCode/friendly-snippets pack that
-- NvChad loads into the same source (their default priority is 1000).
local function add(ft, snippets)
    ls.add_snippets(ft, snippets, { default_priority = 2000 })
end

function M.setup()
    ls.config.setup({ enable_autosnippets = false })

    -- Valid in any filetype: plain comment markers only.
    add("all", {
        s({ trig = "todo", dscr = "TODO note" }, { t("TODO: "), i(1) }),
        s({ trig = "fixme", dscr = "FIXME note" }, { t("FIXME: "), i(1) }),
        s({ trig = "note", dscr = "NOTE" }, { t("NOTE: "), i(1) }),
    })

    add("java", {
        -- Common actions.
        s({ trig = "main", dscr = "main method" }, fmt([[
public static void main(String[] args) {{
    {}
}}
]], { i(1) })),
        s({ trig = "sout", dscr = "System.out.println" }, fmt("System.out.println({});", { i(1) })),
        s({ trig = "if", dscr = "if statement" }, fmt([[
if ({}) {{
    {}
}}
]], { i(1, "condition"), i(2) })),
        s({ trig = "fori", dscr = "indexed for loop" }, fmt([[
for (int {1} = 0; {1} < {2}; {1}++) {{
    {3}
}}
]], { i(1, "i"), i(2, "n"), i(3) })),
        s({ trig = "foreach", dscr = "for-each loop" }, fmt([[
for ({} : {}) {{
    {}
}}
]], { i(1, "Type item"), i(2, "collection"), i(3) })),
        s({ trig = "try", dscr = "try/catch" }, fmt([[
try {{
    {}
}} catch ({} {}) {{
    {}
}}
]], { i(1), i(2, "Exception"), i(3, "e"), i(4) })),

        -- Collections.
        s({ trig = "list", dscr = "mutable ArrayList" }, fmt("List<{}> {} = new ArrayList<>();", { i(1, "String"), i(2, "items") })),
        s({ trig = "listof", dscr = "immutable List.of" }, fmt("List<{}> {} = List.of({});", { i(1, "String"), i(2, "items"), i(3) })),
        s({ trig = "map", dscr = "mutable HashMap" }, fmt("Map<{}, {}> {} = new HashMap<>();", { i(1, "String"), i(2, "Integer"), i(3, "counts") })),
        s({ trig = "mapof", dscr = "immutable Map.of" }, fmt("Map<{}, {}> {} = Map.of({});", { i(1, "String"), i(2, "Integer"), i(3, "counts"), i(4) })),
        s({ trig = "set", dscr = "mutable HashSet" }, fmt("Set<{}> {} = new HashSet<>();", { i(1, "String"), i(2, "seen") })),
        s({ trig = "setof", dscr = "immutable Set.of" }, fmt("Set<{}> {} = Set.of({});", { i(1, "String"), i(2, "allowed"), i(3) })),
        s({ trig = "deque", dscr = "ArrayDeque" }, fmt("Deque<{}> {} = new ArrayDeque<>();", { i(1, "String"), i(2, "queue") })),
        s({ trig = "stream", dscr = "stream pipeline" }, fmt([[
{}.stream()
    .map({})
    .toList();
]], { i(1, "items"), i(2, "item -> item") })),
    })

    add("python", {
        s({ trig = "def", dscr = "function" }, fmt([[
def {}({}):
    {}
]], { i(1, "name"), i(2), i(3) })),
        s({ trig = "if", dscr = "if statement" }, fmt([[
if {}:
    {}
]], { i(1, "condition"), i(2) })),
        s({ trig = "for", dscr = "for loop" }, fmt([[
for {} in {}:
    {}
]], { i(1, "item"), i(2, "items"), i(3) })),
        s({ trig = "main", dscr = "entry point" }, fmt([[
def main() -> None:
    {}

if __name__ == "__main__":
    main()
]], { i(1) })),
        s({ trig = "list", dscr = "list literal" }, fmt("{}: list[{}] = []", { i(1, "items"), i(2, "str") })),
        s({ trig = "dict", dscr = "dict literal" }, fmt("{}: dict[{}, {}] = {{}}", { i(1, "mapping"), i(2, "str"), i(3, "int") })),
        s({ trig = "set", dscr = "set literal" }, fmt("{}: set[{}] = set()", { i(1, "seen"), i(2, "str") })),
        s({ trig = "comp", dscr = "list comprehension" }, fmt("[{} for {} in {}]", { i(1, "item"), i(2, "item"), i(3, "items") })),
    })

    add("lua", {
        s({ trig = "fn", dscr = "local function" }, fmt([[
local function {}({})
    {}
end
]], { i(1, "name"), i(2), i(3) })),
        s({ trig = "if", dscr = "if statement" }, fmt([[
if {} then
    {}
end
]], { i(1, "condition"), i(2) })),
        s({ trig = "forp", dscr = "pairs loop" }, fmt([[
for {} in pairs({}) do
    {}
end
]], { i(1, "key, value"), i(2, "tbl"), i(3) })),
        s({ trig = "fori", dscr = "ipairs loop" }, fmt([[
for {}, {} in ipairs({}) do
    {}
end
]], { i(1, "i"), i(2, "value"), i(3, "list"), i(4) })),
        s({ trig = "tbl", dscr = "table literal" }, fmt("local {} = {{\n    {}\n}}", { i(1, "tbl"), i(2) })),
    })

    add("bash", {
        s({ trig = "if", dscr = "if statement" }, fmt([=[
if [[ {} ]]; then
    {}
fi
]=], { i(1, "condition"), i(2) })),
        s({ trig = "for", dscr = "for loop" }, fmt([[
for {} in {}; do
    {}
done
]], { i(1, "item"), i(2, '"$@"'), i(3) })),
        s({ trig = "fn", dscr = "function" }, fmt([[
{}() {{
    {}
}}
]], { i(1, "name"), i(2) })),
        s({ trig = "case", dscr = "case statement" }, fmt([[
case {} in
    {})
        {}
        ;;
    *)
        ;;
esac
]], { i(1, '"$1"'), i(2, "pattern"), i(3) })),
    })

    add("javascript", {
        s({ trig = "fn", dscr = "function" }, fmt([[
function {}({}) {{
    {}
}}
]], { i(1, "name"), i(2), i(3) })),
        s({ trig = "arrow", dscr = "arrow function" }, fmt("const {} = ({}) => {{\n    {}\n}};", { i(1, "name"), i(2), i(3) })),
        s({ trig = "if", dscr = "if statement" }, fmt([[
if ({}) {{
    {}
}}
]], { i(1, "condition"), i(2) })),
        s({ trig = "forof", dscr = "for...of loop" }, fmt([[
for (const {} of {}) {{
    {}
}}
]], { i(1, "item"), i(2, "items"), i(3) })),
        s({ trig = "arr", dscr = "array literal" }, fmt("const {} = [{}];", { i(1, "items"), i(2) })),
        s({ trig = "obj", dscr = "object literal" }, fmt("const {} = {{\n    {}\n}};", { i(1, "obj"), i(2) })),
        s({ trig = "map", dscr = "Map" }, fmt("const {} = new Map();", { i(1, "map") })),
        s({ trig = "set", dscr = "Set" }, fmt("const {} = new Set();", { i(1, "set") })),
    })

    -- TypeScript and React buffers do not inherit their parent filetype.
    ls.filetype_extend("typescript", { "javascript" })
    ls.filetype_extend("typescriptreact", { "typescript" })
    ls.filetype_extend("javascriptreact", { "javascript" })
end

return M
