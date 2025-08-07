local default_state = {
	split = {
		buf = -1,
		win = -1,
	},
	prompt_float = {
		buf = -1,
		win = -1,
	},
	current_line = 0,
	prompt_line_numbers = {},
	api_settings = {
		converstaion_mode = false,
	},
	response = {
		id = nil,
	},
}

---@class AiChat
local M = {}

function M.setup(opts)
	opts = opts or {}

	-- TODO: abstract initial state to account for different llm provider api configurations
	assert(opts["state"]["llm_provider"], "missing key `llm_provider` in options")
	M.state = vim.tbl_deep_extend("keep", opts["state"] or {}, default_state)

	-- autocommands
	local augroup = vim.api.nvim_create_augroup("Ai-Chat", { clear = true })
end

return M
