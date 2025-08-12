local M = {}

function M.open_split_win(opts)
	opts = opts or {}
	local win_width = math.floor((opts.width or 0.75) * vim.o.columns)
	local win_height = math.floor((opts.height or 0.5) * vim.o.lines)

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
		footer = " [<Ctrl+s> to send] ",
		footer_pos = "right",
	}

	-- settings
	local win = vim.api.nvim_open_win(buf, true, win_opts)
	vim.cmd("startinsert")
	vim.api.nvim_set_option_value("wrap", true, { win = win })
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

	return { buf = buf, win = win }
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

return M
