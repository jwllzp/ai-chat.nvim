local M = {}

M.defaults = {
	provider = "openai",
	conversation = true,
	windows = {
		split = { width = 0.5, height = 0.5 },
		float = { width = 0.5, height = 0.5 },
	},
	keymaps = {
		toggle_prompt = "<leader>c",
		toggle_split = "<leader><leader>",
		prev_prompt = "<leader>p",
		next_prompt = "<leader>n",
		yank_snippet = "ys",
		quit = "q",
		send = "<C-s>",
	},
}

function M.setup(opts)
	opts = vim.tbl_deep_extend("force", M.defaults, opts or {})
	-- Back-compat: old misspelling converstaion_mode
	if opts and opts.api_settings and opts.api_settings.converstaion_mode ~= nil then
		opts.conversation = opts.api_settings.converstaion_mode
	end
	M.options = opts
	return opts
end

function M.get()
	return M.options or M.defaults
end

return M
