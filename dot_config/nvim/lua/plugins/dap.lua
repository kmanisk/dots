return {
    {
        "mfussenegger/nvim-dap",
        cmd = { "DapContinue", "DapToggleBreakpoint", "DapNew" },
        keys = {
            {
                "<leader>b",
                function()
                    require("persistent-breakpoints.api").toggle_breakpoint()
                end,
                desc = "Toggle breakpoint",
            },
            {
                "<leader>Db",
                function()
                    require("persistent-breakpoints.api").toggle_breakpoint()
                end,
                desc = "Toggle breakpoint",
            },
            {
                "<leader>DB",
                function()
                    require("persistent-breakpoints.api").set_conditional_breakpoint()
                end,
                desc = "Conditional breakpoint",
            },
            {
                "<leader>Dl",
                function()
                    require("persistent-breakpoints.api").set_log_point()
                end,
                desc = "Log point",
            },
            { "<leader>Dc", function() require("dap").continue() end, desc = "Continue" },
            { "<leader>Do", function() require("dap").step_over() end, desc = "Step over" },
            { "<leader>Di", function() require("dap").step_into() end, desc = "Step into" },
            { "<leader>DI", function() require("dap").step_out() end, desc = "Step out" },
            { "<leader>Dp", function() require("dap").pause() end, desc = "Pause" },
            { "<leader>Dr", function() require("dap").restart() end, desc = "Restart" },
            { "<leader>Dt", function() require("dap").terminate() end, desc = "Terminate" },
            { "<leader>Dq", function() require("dap").close() end, desc = "Close debug session" },
            { "<leader>Du", function() require("dapui").toggle() end, desc = "Toggle debugger UI" },
            {
                "<leader>De",
                function() require("dapui").eval() end,
                mode = { "n", "v" },
                desc = "Evaluate expression",
            },
        },
        dependencies = {
            "rcarriga/nvim-dap-ui",
            "theHamsta/nvim-dap-virtual-text",
            "nvim-neotest/nvim-nio",
            "Weissle/persistent-breakpoints.nvim",
        },
        config = function()
            local dap = require("dap")
            local dapui = require("dapui")

            -- Breakpoints survive restarts. always_reload is needed because
            -- auto-session restores buffers after the initial BufReadPost.
            require("persistent-breakpoints").setup({
                load_breakpoints_event = { "BufReadPost" },
                always_reload = true,
            })

            dapui.setup({})
            require("nvim-dap-virtual-text").setup({
                commented = true,
                virt_text_pos = "eol",
            })

            dap.listeners.after.event_initialized["dapui_config"] = function()
                dapui.open()
            end
            dap.listeners.before.event_terminated["dapui_config"] = function()
                dapui.close()
            end
            dap.listeners.before.event_exited["dapui_config"] = function()
                dapui.close()
            end

            vim.api.nvim_set_hl(0, "DapStoppedLine", { default = true, link = "Visual" })
            vim.fn.sign_define("DapBreakpoint", { text = "B", texthl = "DiagnosticError" })
            vim.fn.sign_define("DapBreakpointCondition", { text = "C", texthl = "DiagnosticWarn" })
            vim.fn.sign_define("DapLogPoint", { text = "L", texthl = "DiagnosticInfo" })
            vim.fn.sign_define("DapStopped", { text = ">", texthl = "DiagnosticOk", linehl = "DapStoppedLine" })

            -- Python: use Mason's debugpy adapter when it is installed.
            local debugpy_adapter = vim.fn.stdpath("data") .. "/mason/packages/debugpy/debugpy-adapter"
            if vim.fn.executable(debugpy_adapter) == 1 then
                dap.adapters.python = {
                    type = "executable",
                    command = debugpy_adapter,
                    args = {},
                }
                dap.configurations.python = {
                    {
                        type = "python",
                        request = "launch",
                        name = "Launch file",
                        program = "${file}",
                        pythonPath = function()
                            return vim.fn.exepath("python3")
                        end,
                        console = "integratedTerminal",
                    },
                }
            end
        end,
    },
}
