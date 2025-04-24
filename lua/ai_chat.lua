local curl = require("plenary.curl")

local M = {}

M.setup = function()
	-- nothing
end

M.state = {
	split = {
		buf = -1,
		win = -1,
	},
	current_line = 0
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

	-- settings
	local win = vim.api.nvim_open_win(buf, true, win_opts)
	vim.api.nvim_set_option_value("wrap", true, { win = win })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	return { buf=buf, win=win, }
end

--- returns each line in the response as an element in a table
---@param prompt string
---@param output_text string: raw string from response
---@param split_cols integer: number of columns in split
M.format_output = function(prompt, output_text, split_cols)
	local sep1 = string.rep("=", split_cols)
	local sep2 = string.rep("-", split_cols)
	local lines = vim.split(
		sep1 .. "\n".. prompt .. "\n".. sep2 .."\n" .. output_text, "\n",
		{plain=true}
	)
	return lines
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

	-- create window if not exists
	if not vim.api.nvim_win_is_valid(M.state.split.win) then
		M.state.split = M.open_floating_win({ buf = M.state.split.buf })
	end

	-- insert output
	local lines = M.format_output(
		prompt,
		output_text,
		vim.api.nvim_win_get_width(M.state.split.win)
	)
	local start = M.state.current_line
	local end_ = M.state.current_line + #lines
	vim.api.nvim_set_option_value("modifiable", true, { buf = M.state.split.buf })
	vim.api.nvim_buf_set_lines(M.state.split.buf, start, end_, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = M.state.split.buf })

	-- focus on newest prompt
	vim.api.nvim_win_set_cursor(M.state.split.win, {start+2, 0})
	vim.api.nvim_command("normal! zt")

	M.state.current_line = end_
end


vim.api.nvim_create_user_command("Aichat", function()
	M.chat()
end, {})

vim.keymap.set("n", "<leader><leader>", function()
	if not vim.api.nvim_win_is_valid(M.state.split.win) then
		M.state.split = M.open_floating_win({ buf = M.state.split.buf })
	else
		vim.api.nvim_win_hide(M.state.split.win)
	end
end, { desc = "Toggle floating split" })

return M
