local st_mod = require("aichat.state")
local st = st_mod.get()
local cfg = require("aichat.config").get()

local M = {}

local function set_autocmds(buf)
	vim.api.nvim_create_autocmd({ "BufEnter" }, {
		buffer = buf,
		group = st_mod.augroup,
		command = "stopinsert",
		desc = "Make sure split is entered in normal mode",
	})
end

local function set_keymaps(buf)
	local km = cfg.keymaps
	vim.keymap.set("n", km.prev_prompt, M.move_to_prev_prompt, { buffer = buf, noremap = true, silent = true })
	vim.keymap.set("n", km.next_prompt, M.move_to_next_prompt, { buffer = buf, noremap = true, silent = true })
	vim.keymap.set(
		"n",
		km.yank_snippet,
		require("aichat.actions").yank_code_snippet,
		{ buffer = buf, noremap = true, silent = true }
	)
	vim.keymap.set("n", km.quit, function()
		if vim.api.nvim_win_is_valid(st.split.win) then
			vim.api.nvim_win_hide(st.split.win)
		end
	end, { buffer = buf, noremap = true, silent = true })
end

function M.open(opts)
	opts = opts or {}
	local width = math.floor((opts.width or cfg.windows.split.width) * vim.o.columns)
	local height = math.floor((opts.height or cfg.windows.split.height) * vim.o.lines)

	local buf = vim.api.nvim_buf_is_valid(st.split.buf) and st.split.buf or vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_open_win(buf, true, { split = "right", width = width, height = height, style = "minimal" })

	vim.api.nvim_set_option_value("wrap", true, { win = win })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

	st.split = { buf = buf, win = win }
	set_autocmds(buf)
	set_keymaps(buf)
	return st.split
end

function M.move_to_prev_prompt()
	local line = vim.api.nvim_win_get_cursor(st.split.win)[1] - 1
	if line <= 1 then
		line = st.prompt_line_numbers[1]
	else
		while not vim.tbl_contains(st.prompt_line_numbers, line) do
			line = line - 1
		end
	end
	vim.api.nvim_win_set_cursor(st.split.win, { line, 0 })
end

function M.move_to_next_prompt()
	local line = vim.api.nvim_win_get_cursor(st.split.win)[1] + 1
	local max_line = st.prompt_line_numbers[#st.prompt_line_numbers]
	if line >= max_line then
		line = max_line
	else
		while not vim.tbl_contains(st.prompt_line_numbers, line) do
			line = line + 1
		end
	end
	vim.api.nvim_win_set_cursor(st.split.win, { line, 0 })
end

local function format_output(prompt, output_text, cols)
	local sep = string.rep("-", cols)
	return vim.split(sep .. "\n# " .. prompt .. "\n\n" .. output_text .. "\n", "\n", { plain = true })
end

function M.write_response(prompt, output_text)
	if not vim.api.nvim_win_is_valid(st.split.win) then
		M.open({})
	end
	local cols = vim.api.nvim_win_get_width(st.split.win)
	local lines = format_output(prompt, output_text, cols)
	local start_ = st.current_line
	local finish = st.current_line + #lines

	vim.api.nvim_set_option_value("modifiable", true, { buf = st.split.buf })
	vim.api.nvim_buf_set_lines(st.split.buf, start_, finish, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = st.split.buf })

	vim.api.nvim_win_set_cursor(st.split.win, { start_ + 2, 0 })
	vim.cmd("normal! zt")
	table.insert(st.prompt_line_numbers, start_ + 2)

	st.current_line = finish
end

return M
