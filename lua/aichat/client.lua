local st_mod = require("aichat.state")
local split = require("aichat.ui.split")
local providers = require("aichat.providers")
local util = require("aichat.util")
local cache_mod = require("aichat.caches")

local M = {}

function M.chat(prompt)
	local st = st_mod.get()
	local p = util.trim(prompt or "")
	if #p == 0 then
		return
	end
	if not vim.api.nvim_win_is_valid(st.split.win) then
		split.open({})
	end
	local provider = providers.get(st.provider)
	provider.send(p, function(resp)
		M.update_response_id(resp.id)
		split.write_response(p, resp.text or "")
	end)
end

function M.update_response_id(response_id)
	local cache = cache_mod.get_converstation_state()
	cache.last_response_id = response_id
	st_mod.set_response_id(response_id)
	cache_mod.cache_conversation_state(cache)
end

return M
