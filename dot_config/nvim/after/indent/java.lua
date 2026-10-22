-- Java indentation override: ensure C-indent options survive runtime scripts
vim.bo.cindent = true
vim.bo.smartindent = false
vim.bo.indentexpr = ""
vim.opt_local.cinoptions = "j1,(0,ws,m1"
