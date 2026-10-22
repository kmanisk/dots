-- lua/plugins/autopairs.lua
-- Intelligent multi-line expansion and spacing for all bracket pairs: (), {}, []
return {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    opts = {
        check_ts = true,
        enable_check_bracket_line = true,
        map_cr = true,
        fast_wrap = {},
        disable_filetype = { "TelescopePrompt", "vim" },
    },
    config = function(_, opts)
        local npairs = require("nvim-autopairs")
        local Rule = require("nvim-autopairs.rule")
        local cond = require("nvim-autopairs.conds")

        npairs.setup(opts)

        -- 1. Symmetric space padding inside matching pairs:
        -- {|} + <space> -> { | }
        -- (|) + <space> -> ( | )
        -- [|] + <space> -> [ | ]
        -- { | } + <BS> -> {|}
        npairs.add_rules({
            Rule(" ", " ")
                :with_pair(function(args)
                    local pair = args.line:sub(args.col - 1, args.col)
                    return vim.tbl_contains({ "()", "{}", "[]" }, pair)
                end)
                :with_move(cond.none())
                :with_cr(cond.none())
                :with_del(function(args)
                    local col = vim.api.nvim_win_get_cursor(0)[2]
                    local context = args.line:sub(col - 1, col + 2)
                    return vim.tbl_contains({ "(  )", "{  }", "[  ]" }, context)
                end),
            Rule("( ", " )")
                :with_pair(cond.none())
                :with_move(function(args)
                    return args.char == ")"
                end)
                :use_key(")"),
            Rule("{ ", " }")
                :with_pair(cond.none())
                :with_move(function(args)
                    return args.char == "}"
                end)
                :use_key("}"),
            Rule("[ ", " ]")
                :with_pair(cond.none())
                :with_move(function(args)
                    return args.char == "]"
                end)
                :use_key("]"),
        })

        -- Cmp autopairs integration
        local cmp_ok, cmp = pcall(require, "cmp")
        if cmp_ok then
            local cmp_autopairs_ok, cmp_autopairs = pcall(require, "nvim-autopairs.completion.cmp")
            if cmp_autopairs_ok then
                cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
            end
        end
    end,
}
