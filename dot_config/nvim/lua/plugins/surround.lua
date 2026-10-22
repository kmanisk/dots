return {
	"kylechui/nvim-surround",
	version = "*",
	event = "VeryLazy",
	config = function()
		require("nvim-surround").setup({})
	end,
	cond = function()
		return not vim.g.vscode -- Exclude this plugin in VSCode
	end,
}
