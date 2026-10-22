-- Disabled: vim-sneak covers labelled motion, so Hop is kept as an opt-in extra.
return {
  "smoka7/hop.nvim",
  version = "*",
  enabled = false,
  cond = function()
    return not vim.g.vscode
  end,
  opts = {
    keys = "etovxqpdygfblzhckisuran",
  },
}
