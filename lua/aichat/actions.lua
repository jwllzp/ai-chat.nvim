local ts = require("aichat.ts")
local st = require("aichat.state").get()

local M = {}

function M.yank_code_snippet()
	if ts.inside_markdown_code_fence() then
		local ts_utils = require("nvim-treesitter.ts_utils")
		local node = ts_utils.get_node_at_cursor()
		while node:parent() ~= nil do
			node = node:parent()
		end
		if node then
			local sr, sc, er = node:range()
			local last_line = vim.api.nvim_buf_get_lines(st.split.buf, er - 1, er, false)[1]
			vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
			vim.cmd("normal! v")
			vim.api.nvim_win_set_cursor(0, { er, #last_line - 1 })
			vim.cmd("normal! y")
			vim.cmd("normal! <")
		end
	end
end

return M
