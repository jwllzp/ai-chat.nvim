local M = {}

local chat_dir = vim.fn.stdpath("data") .. "/aichat"

function M.setup()
	print("running seupt")
	if vim.fn.isdirectory(chat_dir) == 0 then
		vim.fn.mkdir(chat_dir, "p")
	end

	local path, f

	path = chat_dir .. "/chat.md"
	if vim.fn.filereadable(path) == 0 then
		f = io.open(path, "w")
		if f then
			f:close()
		end
	end

	path = chat_dir .. "/conversation_state.json"
	if vim.fn.filereadable(path) == 0 then
		f = io.open(path, "w")
		if f then
			f:write('{\n\t"last_response_id": null\n}')
			f:close()
		end
	end
end

---@return table{a?: string}
function M.get_converstation_state()
	local path = chat_dir .. "/conversation_state.json"

	local f = io.open(path, "r")
	if not f then
		error("Failed to open file: " .. path)
	end
	local content = f:read("*a")
	f:close()

	return vim.fn.json_decode(content)
end

function M.cache_conversation_state(state)
	local path = chat_dir .. "/conversation_state.json"
	local f = io.open(path, "w")
	if not f then
		error("Failed to open file: " .. path)
	end

	f:write(vim.fn.json_encode(state))
	f:close()
end

return M
