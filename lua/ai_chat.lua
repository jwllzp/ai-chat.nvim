local curl = require("plenary.curl")

local M = {}

M.setup = function()
	-- nothing
end

M.state = {
	split = {
		buf = -1,
		win = -1,
	}
}

--- create a floating window
M.open_floating_win = function(opts)
	opts = opts or {}
	local win_width = math.floor((opts.width or 0.5) * vim.o.columns)
	local win_height = math.floor((opts.height or 0.5) * vim.o.lines)
	local row = math.floor((vim.o.lines - win_height) / 2)
	local col = math.floor((vim.o.columns - win_width) / 2)

	local buf = nil
	if vim.api.nvim_buf_is_valid(opts.buf) then
		buf = opts.buf
	else
		buf = vim.api.nvim_create_buf(false, true)
	end

	local win_opts = {
		split = "right",
		width = win_width,
		height = win_height,
		-- row = row,
		-- col = col,
		style = "minimal",
		-- border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, true, win_opts)
	vim.api.nvim_set_option_value("wrap", true, { win = win })

	return { buf=buf, win=win }
end

--- makes request to api and prints response
---@return nil: api response
M.chat = function()
	local prompt = vim.fn.input("Write prompt: ")
	vim.api.nvim_out_write("\n")
	local res = curl.post("https://api.openai.com/v1/responses", {
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. os.getenv("OPENAI_API_KEY"),
		},
		body = vim.fn.json_encode({
			model = "gpt-4o-mini",
			input = prompt,
		}),
	})
	local data = vim.json.decode(res.body)
	local output_text = data["output"][1]["content"][1]["text"]
	local lines = vim.split(output_text, "\n", {plain=true})

	-- create window if not exists
	if not vim.api.nvim_win_is_valid(M.state.split.win) then
		M.state.split = M.open_floating_win({ buf = M.state.split.buf })
	end

	-- clear buffer contents
	vim.api.nvim_buf_set_lines(M.state.split.buf, 0, -1, false, {})

	-- insert output
	vim.api.nvim_buf_set_lines(M.state.split.buf, 0, #lines, false, lines)
end


vim.api.nvim_create_user_command("Aichat", function()
	M.chat()
end, {})

return M
