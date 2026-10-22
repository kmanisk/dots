return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        {
            "nvim-telescope/telescope-live-grep-args.nvim",
            -- This will not install any breaking changes.
            -- For major updates, this must be adjusted manually.
            version = "^1.0.0",
        },
        -- Native fzf sorter: the Lua sorter is the bottleneck on live_grep
        -- over large trees. Compiled with make, loaded only if the .so exists.
        {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "make",
        },
        { "debugloop/telescope-undo.nvim" },
    },
    keys = {
        { "<leader>fu", "<cmd>Telescope undo<cr>", desc = "Undo history" },
    },
    config = function()
        local telescope = require("telescope")

        -- first setup telescope
        telescope.setup({
            defaults = {
                -- Build output and editor metadata are never worth listing.
                -- ripgrep only honours .gitignore inside a git repository, so
                -- the globs are explicit instead of relying on .gitignore.
                file_ignore_patterns = {
                    "%.class$",
                    "^out/",
                    "/out/",
                    "^target/",
                    "/target/",
                    "^build/",
                    "/build/",
                    "^dist/",
                    "/dist/",
                    "^node_modules/",
                    "/node_modules/",
                    "%.git/",
                    "%.settings/",
                    "%.classpath$",
                    "%.project$",
                },
                vimgrep_arguments = {
                    "rg",
                    "--color=never",
                    "--no-heading",
                    "--with-filename",
                    "--line-number",
                    "--column",
                    "--smart-case",
                    "--glob=!*.class",
                    "--glob=!out",
                    "--glob=!target",
                    "--glob=!build",
                    "--glob=!dist",
                    "--glob=!node_modules",
                    "--glob=!.git",
                    "--glob=!.settings",
                    "--glob=!*.classpath",
                    "--glob=!*.project",
                },
                -- Prompt on top, results directly below it, best match first.
                -- The default (prompt at the bottom) stacks short result lists
                -- against the lower edge and leaves a large dead area above.
                prompt_position = "top",
                sorting_strategy = "ascending",
                layout_strategy = "horizontal",
                layout_config = {
                    -- Use almost the whole window instead of the default 0.8.
                    width = 0.96,
                    height = 0.9,
                    -- Show the preview at normal widths; the default cutoff of
                    -- 120 hides it on a large-font terminal.
                    preview_cutoff = 100,
                    horizontal = {
                        -- Telescope's horizontal default puts the prompt at the
                        -- bottom, which stacks short result lists against the
                        -- lower edge and leaves a dead area above them.
                        prompt_position = "top",
                        preview_width = 0.6,
                        results_width = 0.4,
                    },
                },
            },
            pickers = {
                -- Grep benefits from a wider preview than the file list.
                live_grep = {
                    layout_config = { preview_width = 0.62 },
                },
                live_grep_args = {
                    layout_config = { preview_width = 0.62 },
                },
            },
        })

        -- then load the extensions. fzf-native is a compiled module, so a
        -- broken or missing build must not break Telescope itself.
        telescope.load_extension("live_grep_args")
        pcall(telescope.load_extension, "fzf")
        telescope.load_extension("undo")
    end,
    cond = function()
        return not vim.g.vscode -- Exclude this plugin in VSCode
    end,
}
