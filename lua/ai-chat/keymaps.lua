local core = require("ai-chat.core")
local api = require("ai-chat.api")
local utils = require("ai-chat.utils")
local windows = require("ai-chat.windows")

local M = {}

M.set_prompt_float_window_keymaps = function(buf)
  vim.keymap.set("n", "<CR>", function()
    local lines = vim.api.nvim_buf_get_lines(core.state.prompt_float.buf, 0, -1, false)
    local prompt = table.concat(lines, "\n")
    vim.api.nvim_buf_set_lines(core.state.prompt_float.buf, 0, -1, false, { "" })
    vim.api.nvim_win_close(core.state.prompt_float.win, true)
    api.chat(prompt)
  end, { buffer = buf, nowait = true, silent = true })
end

M.set_split_window_keymaps = function(buf)
  vim.keymap.set("n", "<leader>p", function()
    local line = vim.api.nvim_win_get_cursor(core.state.split.win)[1] - 1
    if line <= 1 then
      line = core.state.prompt_line_numbers[1]
    else
      while not vim.tbl_contains(core.state.prompt_line_numbers, line) do
        line = line - 1
      end
    end
    vim.api.nvim_win_set_cursor(core.state.split.win, {line, 0})
  end, { buffer = buf, noremap = true, silent = true })

  vim.keymap.set("n", "<leader>n", function()
    local line = vim.api.nvim_win_get_cursor(core.state.split.win)[1] + 1
    local max = core.state.prompt_line_numbers[#core.state.prompt_line_numbers]
    if line >= max then line = max else
      while not vim.tbl_contains(core.state.prompt_line_numbers, line) do
        line = line + 1
      end
    end
    vim.api.nvim_win_set_cursor(core.state.split.win, {line, 0})
  end, { buffer = buf, noremap = true, silent = true })

  vim.api.nvim_buf_set_keymap(buf, 'n', 'ys', '', {
    callback = M.yank_code_snippet,
    noremap = true,
    silent = true,
    desc = "[y]ank [s]nippet under cursor"
  })
end

M.yank_code_snippet = function()
  if utils.inside_markdown_code_fence() then
    local ts_utils = require("nvim-treesitter.ts_utils")
    local node = ts_utils.get_node_at_cursor()
    while node:parent() ~= nil do node = node:parent() end
    if node then
      local sr, sc, er, _ = node:range()
      local last_line = vim.api.nvim_buf_get_lines(core.state.split.buf, er-1, er, false)[1]
      vim.api.nvim_win_set_cursor(0, {sr + 1, sc})
      vim.cmd("normal! v")
      vim.api.nvim_win_set_cursor(0, {er, #last_line - 1})
      vim.cmd("normal! y")
      vim.cmd("normal! <")
    end
  end
end

vim.keymap.set("n", "<leader>c", function()
  if not vim.api.nvim_win_is_valid(M.state.prompt_float.win) then
    M.state.prompt_float = windows.open_floating_win({ buf = M.state.prompt_float.buf })
  else
    vim.api.nvim_win_hide(M.state.prompt_float.win)
  end
end)

vim.keymap.set("n", "<leader><leader>", function()
  if not vim.api.nvim_win_is_valid(M.state.split.win) then
    M.state.split = windows.open_split_win({ buf = M.state.split.buf })
  else
    vim.api.nvim_win_hide(M.state.split.win)
  end
end, { desc = "Toggle floating split" })

return M
