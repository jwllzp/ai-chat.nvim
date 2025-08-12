local M = {}

M.augroup = vim.api.nvim_create_augroup("Ai-Chat", { clear = true })

local state = {
	provider = "openai",
	split = { buf = -1, win = -1 },
	prompt_float = { buf = -1, win = -1 },
	current_line = 0,
	prompt_line_numbers = {},
	conversation = true,
	response = { id = nil },
}

function M.get()
	return state
end

function M.set_provider(name)
	state.provider = name
end

function M.set_conversation(enabled)
	state.conversation = enabled
	if not enabled then
		state.response.id = nil
	end
end

return M
