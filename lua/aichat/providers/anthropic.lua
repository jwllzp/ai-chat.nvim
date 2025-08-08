local curl = require("plenary.curl")

local M = {}

function M.send(prompt, cb)
	curl.post("https://api.anthropic.com/v1/messages", {
		headers = {
			["Content-Type"] = "application/json",
			["x-api-key"] = os.getenv("ANTHROPIC_API_KEY") or "",
			["anthropic-version"] = "2023-06-01",
		},
		body = vim.fn.json_encode({
			model = "claude-3-5-haiku-20241022",
			max_tokens = 1024,
			messages = { { role = "user", content = prompt } },
		}),
		callback = function(res)
			vim.schedule(function()
				local ok, data = pcall(vim.json.decode, res.body)
				if not ok then
					cb({ id = nil, text = "Failed to decode response" })
					return
				end
				local text = (data["content"] and data["content"][1] and data["content"][1]["text"]) or ""
				cb({ id = data["id"], text = text })
			end)
		end,
	})
end

return M
