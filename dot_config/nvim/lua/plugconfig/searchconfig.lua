-- Search/replace helpers. Mapped under <leader>R (capital) so they do not
-- collide with the run (<leader>r) or search (<leader>s) prefixes.
local map = vim.keymap.set

map("n", "<leader>Ro", "<CMD>SearchReplaceSingleBufferOpen<CR>", { desc = "Replace: open line" })
map("n", "<leader>Rw", "<CMD>SearchReplaceSingleBufferCWord<CR>", { desc = "Replace: word under cursor" })
map("n", "<leader>RW", "<CMD>SearchReplaceSingleBufferCWORD<CR>", { desc = "Replace: WORD under cursor" })
map("n", "<leader>Rs", "<CMD>SearchReplaceSingleBufferSelections<CR>", { desc = "Replace: selections" })
map("n", "<leader>Re", "<CMD>SearchReplaceSingleBufferCExpr<CR>", { desc = "Replace: expression" })
map("n", "<leader>Rf", "<CMD>SearchReplaceSingleBufferCFile<CR>", { desc = "Replace: file" })

map("n", "<leader>Rbo", "<CMD>SearchReplaceMultiBufferOpen<CR>", { desc = "Replace all buffers: open line" })
map("n", "<leader>Rbw", "<CMD>SearchReplaceMultiBufferCWord<CR>", { desc = "Replace all buffers: word" })
map("n", "<leader>RbW", "<CMD>SearchReplaceMultiBufferCWORD<CR>", { desc = "Replace all buffers: WORD" })
map("n", "<leader>Rbs", "<CMD>SearchReplaceMultiBufferSelections<CR>", { desc = "Replace all buffers: selections" })
map("n", "<leader>Rbe", "<CMD>SearchReplaceMultiBufferCExpr<CR>", { desc = "Replace all buffers: expression" })
map("n", "<leader>Rbf", "<CMD>SearchReplaceMultiBufferCFile<CR>", { desc = "Replace all buffers: file" })

map("v", "<leader>Rs", "<CMD>SearchReplaceSingleBufferVisualSelection<CR>", { desc = "Replace selection" })
map("v", "<leader>Rw", "<CMD>SearchReplaceWithinVisualSelectionCWord<CR>", { desc = "Replace word in selection" })

-- Show replacements in a split while typing.
vim.o.inccommand = "split"
