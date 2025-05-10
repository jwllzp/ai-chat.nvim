local curl = require("plenary.curl")
local core = require("ai-chat.core")
local M = {}

function M.get_last_response_id()
  if core.state.api_settings.converstaion_mode then
    return core.state.response.id
  end
end

function M.format_output(prompt, output_text, split_cols)
  local sep = string.rep("-", split_cols)
  local lines = vim.split(sep .. "\n# " .. prompt .. "\n\n" .. output_text .. "\n", "\n", { plain=true })
  return lines
end

function M.callback_write_response_to_split(prompt, res)
  local data = vim.json.decode(res.body)
  core.state.response.id = data["id"]
  local output_text = data.output[1].content[1].text

  local lines = M.format_output(prompt, output_text, vim.api.nvim_win_get_width(core.state.split.win))
  local start = core.state.current_line
  local _end = start + #lines

  vim.api.nvim_set_option_value("modifiable", true, { buf = core.state.split.buf })
  vim.api.nvim_buf_set_lines(core.state.split.buf, start, _end, false, lines)
  vim.api.nvim_set_option_value("modifiable", false, { buf = core.state.split.buf })

  vim.api.nvim_win_set_cursor(core.state.split.win, {start + 2, 0})
  vim.api.nvim_command("normal! zt")
  table.insert(core.state.prompt_line_numbers, start + 2)
  core.state.current_line = _end
end

function M.chat(prompt)
  local _prompt = string.gsub(prompt, "^%s*(.-)%s*$", "%1")
  if #_prompt == 0 then return end

  if not vim.api.nvim_win_is_valid(core.state.split.win) then
    core.state.split = require("ai-chat.windows").open_split_win({ buf = core.state.split.buf })
  end

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
    end
  })
end

return M
