local curl = require("plenary.curl")

local M = {}

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

return M
