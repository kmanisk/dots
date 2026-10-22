return {
	"folke/zen-mode.nvim",
	keys = {
		{ "<leader>zz", "<cmd>ZenMode<CR>", desc = "Toggle zen mode" },
	},
	cond = function()
		return not vim.g.vscode
	end,
	opts = {
		window = {
			backdrop = 1,
			width = 143,
			height = 1,
			options = {},
		},
		plugins = {
			options = {
				enabled = true,
				ruler = false,
				showcmd = false,
				laststatus = 0,
			},
			twilight = { enabled = false },
			gitsigns = { enabled = false },
			tmux = { enabled = false },
			todo = { enabled = false },
			kitty = {
				enabled = false,
				font = "+4",
			},
			alacritty = {
				enabled = false,
				font = "14",
			},
			wezterm = {
				enabled = false,
				font = "+4",
			},
			neovide = {
				enabled = false,
				scale = 1.2,
				disable_animations = {
					neovide_animation_length = 0,
					neovide_cursor_animate_command_line = false,
					neovide_scroll_animation_length = 0,
					neovide_position_animation_length = 0,
					neovide_cursor_animation_length = 0,
					neovide_cursor_vfx_mode = "",
				},
			},
		},
	},
}
