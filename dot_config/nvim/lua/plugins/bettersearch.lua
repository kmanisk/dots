return {
	"cshuaimin/ssr.nvim",
	module = "ssr",
	cond = function()
		return not vim.g.vscode -- Exclude this plugin in VSCode
	end,
	-- Calling setup is optional.
	config = function()
		require("ssr").setup({
			border = "single",
			min_width = 50,
			min_height = 5,
			max_width = 120,
			max_height = 25,
			adjust_window = true,
			keymaps = {
				close = "q",
				next_match = "n",
				prev_match = "N",
				replace_confirm = "<cr>",
				replace_all = "<leader><cr>",
			},
		})
	end,
}
