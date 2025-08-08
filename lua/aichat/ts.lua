local M = {}

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
		return root:named_descendant_for_range(row, col, row, col)
	end
end

function M.inside_markdown_code_fence()
	local node = M.get_markdown_node_at_cursor()
	while node do
		if node:type() == "code_fence_content" then
			return true
		end
		node = node:parent()
	end
	return false
end

return M
