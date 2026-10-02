return {
	"mikavilpas/yazi.nvim",
	event = "VeryLazy",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	cond = function()
		return not vim.g.vscode
	end,
	opts = {
		-- Open yazi instead of netrw for directories
		open_for_directories = false,
		-- Use floating window
		floating_window_scaling_factor = 0.9,
		-- Yazi's log level
		log_level = vim.log.levels.OFF,
		-- Use the system yazi (already themed by theme-set)
		yazi_floating_window_border = "rounded",
		-- Keep yazi's own config (we manage the theme separately)
		set_keymappings_function = nil,
	},
}
