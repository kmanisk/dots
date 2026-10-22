require("git"):setup({
	order = 1500,
})

require("full-border"):setup({
	type = ui.Border.ROUNDED,
})

require("mime-ext"):setup()

require("zoxide"):setup({
	update_db = true,
})

require("yamb"):setup({
	cli = "fzf",
	jump_notify = true,
})

require("what-size"):setup({
	priority = 400,
	LEFT = "",
	RIGHT = " ",
})

require("copy-file-contents"):setup({
	append_char = "\n",
	notification = true,
	show_filename = false,
})

require("projects"):setup({
	notify = {
		enable = true,
	},
})
