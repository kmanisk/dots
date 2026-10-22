-- File: lua/configs/cmp.lua
local M = {}

M.setup = function()
    -- Load base46 cached highlights for cmp
    dofile(vim.g.base46_cache .. "cmp")

    local cmp = require("cmp")

    -- Autopairs integration: automatically insert parentheses after selecting a function or method
    local cmp_autopairs_ok, cmp_autopairs = pcall(require, "nvim-autopairs.completion.cmp")
    if cmp_autopairs_ok then
        cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
    end

    local nvchad_cmp = require("nvchad.cmp")

    -- Render the full signature like Zed does: "add(String e) : boolean".
    -- jdtls supplies the parameter list and return type in labelDetails. Snippet
    -- entries reuse that field for prose descriptions ("Creates a new variable"),
    -- which does not belong in the menu.
    local function format_entry(entry, item)
        local kinds = require("cmp.types").lsp.CompletionItemKind
        local details = entry.completion_item.labelDetails
        local kind = entry:get_kind()

        if details and kind ~= kinds.Snippet and kind ~= kinds.Text then
            local signature = details.detail or ""
            local result = details.description
            if result and result ~= "" then
                item.abbr = item.abbr .. signature .. " : " .. result
            else
                item.abbr = item.abbr .. signature
            end
        end

        return nvchad_cmp.formatting.format(entry, item)
    end

    -- Load the custom snippet set before cmp, so the luasnip source already
    -- has entries when the first completion menu opens.
    require("configs.snippets").setup()

    local options = {
        snippet = {
            expand = function(args)
                require("luasnip").lsp_expand(args.body)
            end,
        },
        completion = {
            completeopt = "menu,menuone,noselect",
            keyword_length = 1,
        },
        matching = {
            disallow_fuzzy_matching = false,
            disallow_fullfuzzy_matching = false,
            disallow_partial_fuzzy_matching = false,
            disallow_partial_matching = false,
            disallow_prefix_unmatching = false,
        },
        sorting = {
            priority_weight = 2,
            comparators = {
                -- Hand-written snippets (lua/configs/snippets.lua) rank first in
                -- every filetype, before LSP members and jdtls' own snippets.
                function(entry1, entry2)
                    local snip1 = entry1.source and entry1.source.name == "luasnip"
                    local snip2 = entry2.source and entry2.source.name == "luasnip"
                    if snip1 ~= snip2 then
                        return snip1
                    end
                end,
                -- Remaining snippets (jdtls "var", "par", "cast", "sysout") and
                -- keywords are noise inside a member list. Keep real members first
                -- and let the server order stand, which is alphabetical, as in Zed.
                function(entry1, entry2)
                    local kinds = require("cmp.types").lsp.CompletionItemKind
                    local kind1 = entry1:get_kind()
                    local kind2 = entry2:get_kind()
                    local noise = function(kind)
                        return kind == kinds.Snippet or kind == kinds.Keyword
                    end
                    if noise(kind1) ~= noise(kind2) then
                        return noise(kind2)
                    end
                end,
                cmp.config.compare.offset,
                cmp.config.compare.exact,
                cmp.config.compare.score,
                cmp.config.compare.sort_text,
                cmp.config.compare.order,
            },
        },
        mapping = cmp.mapping.preset.insert({
            ["<Tab>"] = cmp.mapping(function(fallback)
                if cmp.visible() then
                    cmp.select_next_item()
                elseif require("luasnip").expand_or_jumpable() then
                    require("luasnip").expand_or_jump()
                else
                    fallback()
                end
            end, { "i", "s" }),
            ["<S-Tab>"] = cmp.mapping(function(fallback)
                if cmp.visible() then
                    cmp.select_prev_item()
                elseif require("luasnip").jumpable(-1) then
                    require("luasnip").jump(-1)
                else
                    fallback()
                end
            end, { "i", "s" }),
            ["<C-n>"] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Select }),
            ["<C-p>"] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Select }),
            ["<CR>"] = cmp.mapping(function(fallback)
                if cmp.visible() then
                    if cmp.get_selected_entry() then
                        cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
                    else
                        cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })
                    end
                else
                    fallback()
                end
            end, { "i", "s" }),
            ["<C-y>"] = cmp.mapping.confirm({ select = true }),
            ["<C-e>"] = cmp.mapping.abort(),
            ["<C-u>"] = cmp.mapping.scroll_docs(-4),
            ["<C-d>"] = cmp.mapping.scroll_docs(4),
            ["<C-b>"] = cmp.mapping.scroll_docs(-4),
            ["<C-f>"] = cmp.mapping.scroll_docs(4),
            ["<C-Space>"] = cmp.mapping.complete(),
            ["<A-i>"] = cmp.mapping.complete(),
        }),
        sources = cmp.config.sources({
            { name = "nvim_lsp", priority = 1000 },
            { name = "nvim_lsp_signature_help", priority = 900 },
            { name = "luasnip", priority = 750 },
            { name = "nvim_lua", priority = 500 },
            { name = "path", priority = 250 },
        }, {
            { name = "buffer", priority = 250, keyword_length = 2 },
        }),
        window = nvchad_cmp.window,
        formatting = {
            -- cmp marks snippet-expandable items with a trailing "~"; jdtls sends
            -- every method that way, so the list ends up littered with tildes.
            expandable_indicator = false,
            fields = nvchad_cmp.formatting.fields,
            format = format_entry,
        },
    }

    cmp.setup(options)
end

return M
