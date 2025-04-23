local curl = require("plenary.curl")

local M = {}

M.setup = function()
	-- nothing
end

--- makes request to api and prints response
---@return nil: api response
M.chat = function()
	local prompt = vim.fn.input("Write prompt: ")
	vim.api.nvim_out_write("\n")
	local res = curl.post("https://api.openai.com/v1/responses", {
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = "Bearer " .. os.getenv("OPENAI_API_KEY"),
		},
		body = vim.fn.json_encode({
			model = "gpt-4o-mini",
			input = prompt,
		}),
	})
	local data = vim.json.decode(res.body)
	print(vim.inspect(data))
end

vim.api.nvim_create_user_command("AiChat", function(opts)
  if opts.args == "chat" then
    M.chat()
  else
    print("Unknown subcommand: " .. opts.args)
  end
end, { nargs = 1 })

return M
