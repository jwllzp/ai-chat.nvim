local core = require("ai-chat.core")
local keymaps = require("ai-chat.keymaps")

local M = {}

function M.open_floating_win(opts)
  opts = opts or {}
  local win_width = math.floor((opts.width or 0.5) * vim.o.columns)
  local win_height = math.floor((opts.height or 0.5) * vim.o.lines)
  local row = math.floor((vim.o.lines - win_height) / 2)
  local col = math.floor((vim.o.columns - win_width) / 2)

  local buf = vim.api.nvim_buf_is_valid(opts.buf) and opts.buf or vim.api.nvim_create_buf(false, true)
  keymaps.set_prompt_float_window_keymaps(buf)

  local float_title = core.state.api_settings.converstaion_mode and " prompt - conversation " or " prompt - ask "

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    border = "rounded",
    title = float_title,
    title_pos = "center",
    footer = " [<Enter> to commit] ",
    footer_pos = "right"
  })

  vim.cmd("startinsert")
  vim.api.nvim_set_option_value("wrap", true, { win = win })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

  return { buf = buf, win = win }
end

function M.open_split_win(opts)
  opts = opts or {}
  local win_width = math.floor((opts.width or 0.5) * vim.o.columns)
  local win_height = math.floor((opts.height or 0.5) * vim.o.lines)

  local buf = vim.api.nvim_buf_is_valid(opts.buf) and opts.buf or vim.api.nvim_create_buf(false, true)
  keymaps.set_split_window_keymaps(buf)

  local win = vim.api.nvim_open_win(buf, true, {
    split = "right",
    width = win_width,
    height = win_height,
    style = "minimal",
  })

  vim.api.nvim_set_option_value("wrap", true, { win = win })
  vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })

  return { buf = buf, win = win }
end

return M
