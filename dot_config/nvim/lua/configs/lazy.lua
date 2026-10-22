return {
  defaults = { lazy = true },
  install = { colorscheme = { "nvchad" } },
  rocks = {
    enabled = false,
  },

  ui = {
    icons = {
      ft = "",
      lazy = "󰂠 ",
      loaded = "",
      not_loaded = "",
    },
  },

  performance = {
    rtp = {
      disabled_plugins = {
        "2html_plugin",
        "tohtml",
        "getscript",
        "getscriptPlugin",
        "gzip",
        "logipat",
        "netrw",
        "netrwPlugin",
        "netrwSettings",
        "netrwFileHandlers",
        "matchit",
        "tar",
        "tarPlugin",
        "rrhelper",
        "spellfile_plugin",
        "vimball",
        "vimballPlugin",
        "zip",
        "zipPlugin",
        "tutor",
        "rplugin",
        "syntax",
        "synmenu",
        "optwin",
        "compiler",
        "bugreport",
        -- uncomment this line to make the after/pluins to work 
        -- add langname.lua to make lang specifc option to work
        -- like for ex : python.lua or java.lua
        -- default is commented i.e disabled

        "ftplugin",
      },
    },
  },
}
