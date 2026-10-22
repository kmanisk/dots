return {
	"rmagatti/auto-session",
	lazy = false,

	keys = {
		-- Will use Telescope if installed or a vim.ui.select picker otherwise
		{ "<leader>oR", "<cmd>SessionSearch<CR>", desc = "Session search" },
		{ "<leader>oS", "<cmd>SessionSave<CR>", desc = "Save session" },
		{ "<leader>oA", "<cmd>SessionToggleAutoSave<CR>", desc = "Toggle session autosave" },
	},
	---enables autocomplete for opts
	---@module "auto-session"
	---@type AutoSession.Config
	opts = {

		enabled = true, -- Enables/disables auto creating, saving and restoring
		root_dir = vim.fn.stdpath("data") .. "/sessions/", -- Root dir where sessions will be stored
		auto_save = true, -- Enables/disables auto saving session on exit
		auto_restore = true, -- Enables/disables auto restoring session on start
		auto_create = true, -- Enables/disables auto creating new session files. Can take a function that should return true/false if a new session file should be created or not
		suppressed_dirs = { "~/", "~/Downloads", "/" }, -- Suppress session restore/create in root home and transient dirs
		allowed_dirs = nil, -- Allow session restore/create in certain directories
		auto_restore_last_session = false, -- On startup, loads the last saved session if session for cwd does not exist
		git_use_branch_name = false, -- Include git branch name in session name
		lazy_support = true, -- Automatically detect if Lazy.nvim is being used and wait until Lazy is done to make sure session is restored correctly. Does nothing if Lazy isn't being used. Can be disabled if a problem is suspected or for debugging
		bypass_save_filetypes = { "alpha" }, -- Do not save a session when only the start page is open
		close_unsupported_windows = true, -- Close windows that aren't backed by normal file before autosaving a session
		args_allow_single_directory = true, -- Follow normal sesion save/load logic if launched with a single directory as the only argument
		args_allow_files_auto_save = true, -- Allow saving a session even when launched with a file argument (or multiple files/dirs). It does not load any existing session first. While you can just set this to true, you probably want to set it to a function that decides when to save a session when launched with file args. See documentation for more detail
		continue_restore_on_error = true, -- Keep loading the session even if there's an error
		show_auto_restore_notif = false, -- Whether to show a notification when auto-restoring
		cwd_change_handling = true, -- Follow cwd changes, saving a session before change and restoring after
		pre_save_cmds = {
			function()
				pcall(function()
					require("configs.ide").cleanup_empty_unnamed_bufs()
				end)
			end,
		},
		-- No session for this directory: show the start page instead of an
		-- empty scratch buffer. Alpha's own autostart is disabled, so this is
		-- the only place the dashboard is kicked off at startup.
		no_restore_cmds = {
			function()
				pcall(function()
					require("configs.dashboard").start()
				end)
			end,
		},
		post_restore_cmds = {
			function()
				pcall(function()
					require("configs.ide").cleanup_empty_unnamed_bufs()
				end)
			end,
		},
		pre_cwd_changed_cmds = {
			function()
				pcall(function()
					require("configs.ide").cleanup_empty_unnamed_bufs()
				end)
			end,
		},
		post_cwd_changed_cmds = {
			function()
				pcall(function()
					require("configs.ide").cleanup_empty_unnamed_bufs()
				end)
			end,
		},
		lsp_stop_on_restore = false, -- Should language servers be stopped when restoring a session. Can also be a function that will be called if set. Not called on autorestore from startup
		log_level = "error", -- Sets the log level of the plugin (debug, info, warn, error).

		session_lens = {
			load_on_setup = true, -- Initialize on startup (requires Telescope)
			picker_opts = {},
			previewer = false, -- File preview for session picker

			mappings = {
				-- Mode can be a string or a table, e.g. {"i", "n"} for both insert and normal mode
				delete_session = { "i", "<C-D>" },
				alternate_session = { "i", "<C-S>" },
				copy_session = { "i", "<C-Y>" },
			},

			session_control = {
				control_dir = vim.fn.stdpath("data") .. "/auto_session/", -- Auto session control dir, for control files, like alternating between two sessions with session-lens
				control_filename = "session_control.json", -- File name of the session control file
			},
		},
	},
	config = function(_, opts)
		require("auto-session").setup(opts)

		-- Auto-save only runs on exit, so a crash or a forced kill drops the
		-- session. Persist it shortly after the editor loses focus instead.
		local pending = false
		vim.api.nvim_create_autocmd("FocusLost", {
			group = vim.api.nvim_create_augroup("SessionFocusSave", { clear = true }),
			callback = function()
				if pending then
					return
				end
				pending = true
				vim.defer_fn(function()
					pending = false
					if vim.fn.getcmdwintype() ~= "" then
						return
					end
					pcall(require("auto-session").save_session)
				end, 1000)
			end,
			desc = "Persist the session when the editor loses focus",
		})
	end,
	cond = function()
		return not vim.g.vscode -- Exclude this plugin in VSCode
	end,
}
