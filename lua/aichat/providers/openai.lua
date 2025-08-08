local curl = require("plenary.curl")
local st = require("aichat.state").get()

local M = {}

function M.send(prompt, cb)
	curl.post("https://api.openai.com/v1/responses", {
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. (os.getenv("OPENAI_API_KEY") or ""),
		},
		body = vim.fn.json_encode({
			model = "gpt-5",
			input = prompt,
			previous_response_id = st.conversation and st.response.id or nil,
		}),
		callback = function(res)
			vim.schedule(function()
				if res.status < 200 or res.status >= 300 then
					cb({ id = nil, text = "HTTP " .. tostring(res.status) .. "\n" .. (res.body or "") })
					return
				end
				local ok, data = pcall(vim.json.decode, res.body)
				if not ok then
					cb({ id = nil, text = "Failed to decode response" })
					return
				end
				local text = ""
				for _, item in ipairs(data["output"] or {}) do
					if item["type"] == "message" then
						for _, content in ipairs(item["content"] or {}) do
							text = text .. (content["text"] or "") .. "\n\n"
						end
					end
				end
				cb({ id = data["id"], text = text })
			end)
		end,
	})
end

return M
