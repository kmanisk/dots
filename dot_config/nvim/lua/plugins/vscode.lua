return {
	"askfiy/visual_studio_code",
	priority = 100,
	config = function()
		-- vim.cmd([[colorscheme visual_studio_code]])
	end,
	cond = function()
		return not vim.g.vscode -- Exclude this plugin in VSCode
	end,
}
