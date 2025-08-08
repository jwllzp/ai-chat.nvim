local M = {}

M.defaults = {
	provider = "openai",
	conversation = false,
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

function M.setup(user)
	local opts = vim.tbl_deep_extend("force", M.defaults, user or {})
	-- Back-compat: old misspelling converstaion_mode
	if user and user.api_settings and user.api_settings.converstaion_mode ~= nil then
		opts.conversation = user.api_settings.converstaion_mode
	end
	M.options = opts
	return opts
end

function M.get()
	return M.options or M.defaults
end

return M
