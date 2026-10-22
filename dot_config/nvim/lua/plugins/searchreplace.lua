return {
	"roobert/search-replace.nvim",
	cond = function()
		return not vim.g.vscode
	end,
	cmd = {
		"SearchReplaceOpen",
		"SearchReplaceSingleBufferOpen",
		"SearchReplaceSingleBufferSelections",
		"SearchReplaceSingleBufferCWord",
		"SearchReplaceSingleBufferCWORD",
		"SearchReplaceSingleBufferCExpr",
		"SearchReplaceSingleBufferCFile",
		"SearchReplaceSingleBufferVisualSelection",
		"SearchReplaceWithinVisualSelection",
		"SearchReplaceWithinVisualSelectionCWord",
		"SearchReplaceMultiBufferOpen",
		"SearchReplaceMultiBufferSelections",
		"SearchReplaceMultiBufferCWord",
		"SearchReplaceMultiBufferCWORD",
		"SearchReplaceMultiBufferCExpr",
		"SearchReplaceMultiBufferCFile",
	},
	keys = {
		{ "<leader>sr", "<cmd>SearchReplaceOpen<CR>", desc = "Search and replace" },
	},
	config = function()
		require("search-replace").setup({
			default_replace_single_buffer_options = "gcI",
			default_replace_multi_buffer_options = "egcI",
		})
	end,
}
