local M = {}
function M.get(name)
	if name == "anthropic" then
		return require("aichat.providers.anthropic")
	end
	return require("aichat.providers.openai")
end
return M
