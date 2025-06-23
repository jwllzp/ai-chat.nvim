local curl = require("plenary.curl")

local M = {}
local augroup = vim.api.nvim_create_augroup("Ai-Chat", { clear = true })

M.setup = function()
	-- nothing
end

M.state = {
	llm_provider = "anthropic",
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

function M.move_to_prev_prompt()
	local line = vim.api.nvim_win_get_cursor(M.state.split.win)[1] - 1

	if line <= 1 then
		line = M.state.prompt_line_numbers[1]
	else
		while not vim.tbl_contains(M.state.prompt_line_numbers, line) do
			line = line - 1
		end
	end

	vim.api.nvim_win_set_cursor(M.state.split.win, { line, 0 })
end

function M.move_to_next_prompt()
	local line = vim.api.nvim_win_get_cursor(M.state.split.win)[1] + 1
	local max_prompt_line = M.state.prompt_line_numbers[#M.state.prompt_line_numbers]

	if line >= max_prompt_line then
		line = max_prompt_line
	else
		while not vim.tbl_contains(M.state.prompt_line_numbers, line) do
			line = line + 1
		end
	end

	vim.api.nvim_win_set_cursor(M.state.split.win, { line, 0 })
end

function M.set_prompt_float_window_keymaps(buf)
	vim.keymap.set({ "n", "i" }, "<C-s>", function()
		local lines = vim.api.nvim_buf_get_lines(M.state.prompt_float.buf, 0, -1, false)
		local prompt = table.concat(lines, "\n")
		vim.api.nvim_buf_set_lines(M.state.prompt_float.buf, 0, -1, false, { "" })
		vim.api.nvim_win_close(M.state.prompt_float.win, true)
		M.chat(prompt)
	end, { buffer = buf, nowait = true, silent = true, desc = "[Ctrl] [s]end prompt" })

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_hide(M.state.prompt_float.win)
	end, {
		buffer = buf,
		nowait = true,
		silent = true,
	})
end

function M.set_split_window_keymaps(buf)
	vim.keymap.set("n", "<leader>p", M.move_to_prev_prompt, {
		buffer = buf,
		noremap = true,
		silent = true,
		desc = "Navigate to [p]revious prompt",
	})

	vim.keymap.set("n", "<leader>n", M.move_to_next_prompt, {
		buffer = buf,
		noremap = true,
		silent = true,
		desc = "Navigate to [n]ext prompt",
	})

	vim.keymap.set("n", "ys", M.yank_code_snippet, {
		buffer = buf,
		noremap = true,
		silent = true,
		desc = "[y]anc [s]nippet under cursor",
	})

	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_hide(M.state.split.win)
	end, {
		buffer = buf,
		noremap = true,
		silent = true,
		desc = "[q]uit split window",
	})
end

function M.set_split_window_autocomands(buf)
	vim.api.nvim_create_autocmd({ "BufEnter" }, {
		buffer = buf,
		group = augroup,
		command = "stopinsert",
		desc = "make sure split is entered in normal mode",
	})
end

--- create a floating window
function M.open_floating_win(opts)
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

	M.set_prompt_float_window_keymaps(buf)

	local float_title
	if M.state.api_settings.converstaion_mode then
		float_title = " prompt - conversation "
	else
		float_title = " prompt - ask "
	end

	local win_opts = {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = row,
		col = col,
		-- style = "minimal",
		border = "rounded",
		title = float_title,
		title_pos = "center",
		footer = " [<Enter> to commit] ",
		footer_pos = "right",
	}

	-- settings
	local win = vim.api.nvim_open_win(buf, true, win_opts)
	vim.cmd("startinsert")
	vim.api.nvim_set_option_value("wrap", true, { win = win })
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

	return { buf = buf, win = win }
end

--- create a split window
function M.open_split_win(opts)
	opts = opts or {}
	local win_width = math.floor((opts.width or 0.75) * vim.o.columns)
	local win_height = math.floor((opts.height or 0.5) * vim.o.lines)
	local row = math.floor((vim.o.lines - win_height) / 2)
	local col = math.floor((vim.o.columns - win_width) / 2)

	local buf = nil
	if vim.api.nvim_buf_is_valid(opts.buf) then
		buf = opts.buf
	else
		buf = vim.api.nvim_create_buf(false, true)
	end

	M.set_split_window_autocomands(buf)
	M.set_split_window_keymaps(buf)

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

	return { buf = buf, win = win }
end

--- returns each line in the response as an element in a table
--- @param prompt string
--- @param output_text string: raw string from response
function M.format_output(prompt, output_text, split_cols)
	local sep = string.rep("-", split_cols)
	local lines = vim.split(sep .. "\n# " .. prompt .. "\n\n" .. output_text .. "\n", "\n", { plain = true })
	return lines
end

--- callback function to write async response to split
--- @param prompt string
--- @param res table: http response table
--- @return nil
function M.callback_write_response_to_split(prompt, res)
	-- extract output
	local data = vim.json.decode(res.body)
	M.state.response.id = data["id"]

	local output_text
	if M.state.llm_provider == "anthropic" then
		output_text = data["content"][1]["text"]
	else
		output_text = data["output"][1]["content"][1]["text"]
	end

	-- insert output in window
	local lines = M.format_output(prompt, output_text, vim.api.nvim_win_get_width(M.state.split.win))
	local start = M.state.current_line
	local end_ = M.state.current_line + #lines
	vim.api.nvim_set_option_value("modifiable", true, { buf = M.state.split.buf })
	vim.api.nvim_buf_set_lines(M.state.split.buf, start, end_, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = M.state.split.buf })

	-- focus on newest prompt
	vim.api.nvim_win_set_cursor(M.state.split.win, { start + 2, 0 })
	vim.api.nvim_command("normal! zt")

	-- cache location of newly inserted prompt
	table.insert(M.state.prompt_line_numbers, start + 2)

	M.state.current_line = end_
end

--- makes request to api and prints response
--- @param prompt string
--- @return nil: api response
function M.chat(prompt)
	local _prompt = string.gsub(prompt, "^%s*(.-)%s*$", "%1")
	if #_prompt == 0 then
		return
	end

	-- create window if not exists
	if not vim.api.nvim_win_is_valid(M.state.split.win) then
		M.state.split = M.open_split_win({ buf = M.state.split.buf })
	end

	if M.state.llm_provider == "anthropic" then
		curl.post("https://api.anthropic.com/v1/messages", {
			headers = {
				["Content-Type"] = "application/json",
				["x-api-key"] = os.getenv("ANTHROPIC_API_KEY"),
				["anthropic-version"] = "2023-06-01",
			},
			body = vim.fn.json_encode({
				model = "claude-3-5-haiku-20241022",
				max_tokens = 1024,
				messages = {
					{
						role = "user",
						content = _prompt,
					},
				},
			}),
			callback = function(res)
				vim.schedule(function()
					M.callback_write_response_to_split(_prompt, res)
				end)
			end,
		})
	elseif M.state.llm_provider == "open_ai" then
		curl.post("https://api.openai.com/v1/responses", {
			headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. os.getenv("OPENAI_API_KEY"),
			},
			body = vim.fn.json_encode({
				model = "gpt-4o-mini",
				input = _prompt,
				previous_response_id = M.get_last_response_id(),
			}),
			callback = function(res)
				vim.schedule(function()
					M.callback_write_response_to_split(_prompt, res)
				end)
			end,
		})
	else
		print("Invalid llm provider " .. M.state.llm_provider)
	end
end

function M.get_last_response_id()
	if M.state.api_settings.converstaion_mode then
		return M.state.response.id
	end
end

function M.yank_code_snippet()
	--- TODO: needs refactor, see how treesitter-textobjects does selection
	if M.inside_markdown_code_fence() then
		local ts_utils = require("nvim-treesitter.ts_utils")
		local node = ts_utils.get_node_at_cursor()
		while node:parent() ~= nil do
			node = node:parent()
		end
		if node then
			local start_row, start_col, end_row, end_col = node:range()
			local last_line = vim.api.nvim_buf_get_lines(M.state.split.buf, end_row - 1, end_row, false)[1]
			vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
			vim.cmd("normal! v")
			vim.api.nvim_win_set_cursor(0, { end_row, #last_line - 1 })
			vim.cmd("normal! y")
			vim.cmd("normal! <")
		end
	end
end

function M.get_markdown_node_at_cursor()
	local ts = vim.treesitter
	local parsers = require("nvim-treesitter.parsers")

	local bufnr = vim.api.nvim_get_current_buf()
	local lang = parsers.get_buf_lang(bufnr)
	if lang ~= "markdown" then
		return nil
	end

	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1

	local parser = ts.get_parser(bufnr, "markdown")

	for _, tree in ipairs(parser:parse()) do
		local root = tree:root()
		local node = root:named_descendant_for_range(row, col, row, col)
		return node
	end
end

function M.inside_markdown_code_fence()
	local node = M.get_markdown_node_at_cursor()
	while node ~= nil do
		if node:type() == "code_fence_content" then
			return true
		end
		node = node:parent()
	end
	return false
end

function M.toggle_conversation_mode()
	M.state.api_settings.converstaion_mode = not M.state.api_settings.converstaion_mode
	if not M.state.api_settings.converstaion_mode then
		M.state.response.id = nil
	end
	print("[Aichat] conversation mode set to: " .. tostring(M.state.api_settings.converstaion_mode))
end

vim.api.nvim_create_user_command("Aichat", function(opts)
	if opts.args == "toggle_conversation_mode" then
		M.toggle_conversation_mode()
	end
end, {
	desc = "Toggle conversation mode",
	nargs = 1,
	complete = function()
		return { "toggle_conversation_mode" }
	end,
})

vim.keymap.set("n", "<leader>c", function()
	if not vim.api.nvim_win_is_valid(M.state.prompt_float.win) then
		M.state.prompt_float = M.open_floating_win({ buf = M.state.prompt_float.buf })
	else
		vim.api.nvim_win_hide(M.state.prompt_float.win)
	end
end)

vim.keymap.set("n", "<leader><leader>", function()
	if not vim.api.nvim_win_is_valid(M.state.split.win) then
		M.state.split = M.open_split_win({ buf = M.state.split.buf })
	else
		vim.api.nvim_win_hide(M.state.split.win)
	end
end, { desc = "Toggle floating split" })

return M
