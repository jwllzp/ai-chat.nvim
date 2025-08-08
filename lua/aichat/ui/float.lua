local st = require("aichat.state").get()
local cfg = require("aichat.config").get()

local M = {}

local function set_keymaps(buf)
	local km = require("aichat.config").get().keymaps
	local client = require("aichat.client")

	vim.keymap.set({ "n", "i" }, km.send, function()
		local lines = vim.api.nvim_buf_get_lines(st.prompt_float.buf, 0, -1, false)
		local prompt = table.concat(lines, "\n")
		vim.api.nvim_buf_set_lines(st.prompt_float.buf, 0, -1, false, { "" })
		if vim.api.nvim_win_is_valid(st.prompt_float.win) then
			vim.api.nvim_win_close(st.prompt_float.win, true)
		end
		client.chat(prompt)
	end, { buffer = buf, nowait = true, silent = true, desc = "[Ctrl] [s]end prompt" })

	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(st.prompt_float.win) then
			vim.api.nvim_win_hide(st.prompt_float.win)
		end
	end, { buffer = buf, nowait = true, silent = true })
end

function M.open(opts)
	opts = opts or {}
	local width = math.floor((opts.width or cfg.windows.float.width) * vim.o.columns)
	local height = math.floor((opts.height or cfg.windows.float.height) * vim.o.lines)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local buf = vim.api.nvim_buf_is_valid(st.prompt_float.buf) and st.prompt_float.buf
		or vim.api.nvim_create_buf(false, true)
	local title = st.conversation and " prompt - conversation " or " prompt - ask "
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		border = "rounded",
		title = title,
		title_pos = "center",
		footer = " [<Enter> to commit] ",
		footer_pos = "right",
	})
	vim.cmd("startinsert")
	vim.api.nvim_set_option_value("wrap", true, { win = win })
	vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

	st.prompt_float = { buf = buf, win = win }
	set_keymaps(buf)
	return st.prompt_float
end

return M
