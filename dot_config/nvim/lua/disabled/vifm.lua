return {
	"vifm/vifm.vim",
	lazy = false,
	config = function()
		-- Optional additional setup here
	end,
	cond = function()
		return not vim.g.vscode -- Exclude this plugin in VSCode
	end,
}
