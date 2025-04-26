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
	current_line = 0,
	prompt_line_numbers = {},
}

M.move_to_prev_prompt = function()
	local line = vim.api.nvim_win_get_cursor(M.state.split.win)[1] - 1

	if line <= 1 then
		line = M.state.prompt_line_numbers[1]
	else
		while not vim.tbl_contains(M.state.prompt_line_numbers, line) do
			line = line - 1
		end
	end

	vim.api.nvim_win_set_cursor(M.state.split.win, {line, 0})
end

M.move_to_next_prompt = function()
	local line = vim.api.nvim_win_get_cursor(M.state.split.win)[1] + 1
	local max_prompt_line = M.state.prompt_line_numbers[#M.state.prompt_line_numbers]

	if line >= max_prompt_line then
		line = max_prompt_line
	else
		while not vim.tbl_contains(M.state.prompt_line_numbers, line) do
			line = line + 1
		end
	end

	vim.api.nvim_win_set_cursor(M.state.split.win, {line, 0})
end

M.set_prompt_window_keymaps = function()
	vim.api.nvim_buf_set_keymap(M.state.split.buf, 'n', '[[', '', {
		callback = M.move_to_prev_prompt,
		noremap = true,
		silent = true
	})

	vim.api.nvim_buf_set_keymap(M.state.split.buf, 'n', ']]', '', {
		callback = M.move_to_next_prompt,
		noremap = true,
		silent = true
	})

	vim.api.nvim_buf_set_keymap(M.state.split.buf, 'n', 'ys', '', {
		callback = M.yank_code_snippet,
		noremap = true,
		silent = true
	})
end

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

	M.set_prompt_window_keymaps()

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
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

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

--- callback function to write async response to split
--- @param prompt string
--- @param res table: http response table
--- @return nil
M.callback_write_response_to_split = function(prompt, res)
	-- extract output
	local data = vim.json.decode(res.body)
	local output_text = data["output"][1]["content"][1]["text"]

	-- insert output in window
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

	-- cache location of newly inserted prompt
	table.insert(M.state.prompt_line_numbers, start+2)

	M.state.current_line = end_
end

--- makes request to api and prints response
---@return nil: api response
M.chat = function()
	local prompt = vim.fn.input("Write prompt: ")

	-- create window if not exists
	if not vim.api.nvim_win_is_valid(M.state.split.win) then
		M.state.split = M.open_floating_win({ buf = M.state.split.buf })
	end

	curl.post("https://api.openai.com/v1/responses", {
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. os.getenv("OPENAI_API_KEY"),
		},
		body = vim.fn.json_encode({
			model = "gpt-4o-mini",
			input = prompt,
		}),
		callback = function(res)
			vim.schedule(function()
				M.callback_write_response_to_split(prompt, res)
			end)
		end
	})
end

M.yank_code_snippet = function()
	--- TODO: needs refactor, see how treesitter-textobjects does selection
	local ts_utils = require("nvim-treesitter.ts_utils")
	local node = ts_utils.get_node_at_cursor()

	-- Traverse up to find code_fence node
	while node:parent() ~= nil do
		node = node:parent()
	end

	if node then
		local start_row, start_col, end_row, end_col = node:range()
		local last_line = vim.api.nvim_buf_get_lines(M.state.split.buf, end_row-1, end_row, false)[1]
		vim.api.nvim_win_set_cursor(0, {start_row + 1, start_col})
		vim.cmd("normal! v")
		vim.api.nvim_win_set_cursor(0, {end_row, #last_line-1})
		vim.cmd("normal! y")
		vim.cmd("normal! <")
	end
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
