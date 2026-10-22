return {
	"mikavilpas/yazi.nvim",
	event = "VeryLazy",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	keys = {
		{ "<leader>oy", "<cmd>Yazi<CR>", desc = "Open Yazi file manager" },
	},
	cond = function()
		return not vim.g.vscode
	end,
	opts = {
		-- Keep netrw out of directory handling; Oil remains the default explorer.
		open_for_directories = false,
		floating_window_scaling_factor = 0.9,
		log_level = vim.log.levels.OFF,
		yazi_floating_window_border = "single",
		set_keymappings_function = nil,
	},
}
