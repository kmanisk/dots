return {
	cond = function()
		return not vim.g.vscode -- Exclude this plugin in VSCode
	end,
	"ThePrimeagen/vim-be-good",
	lazy = true, -- Lazy load the plugin
	cmd = "VimBeGood", -- Trigger with :VimBeGood command
}
