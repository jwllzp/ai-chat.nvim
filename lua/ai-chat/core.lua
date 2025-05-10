local M = {}

M.state = {
  split = { buf = -1, win = -1 },
  prompt_float = { buf = -1, win = -1 },
  current_line = 0,
  prompt_line_numbers = {},
  api_settings = { converstaion_mode = false },
  response = { id = nil },
}

M.setup = function()
  vim.api.nvim_create_user_command('Aichat', function(opts)
    if opts.args == "toggle_conversation_mode" then
      M.toggle_conversation_mode()
    end
  end, {
  desc = "Toggle conversation mode",
  nargs = 1,
  complete = function()
    return { "toggle_conversation_mode" }
  end
  })
end

M.toggle_conversation_mode = function()
  M.state.api_settings.converstaion_mode = not M.state.api_settings.converstaion_mode
  if not M.state.api_settings.converstaion_mode then
    M.state.response.id = nil
  end
  print("[Aichat] conversation mode set to: ".. tostring(M.state.api_settings.converstaion_mode))
end

return M
