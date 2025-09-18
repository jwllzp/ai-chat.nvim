local cfg = require("aichat.config")
local st_mod = require("aichat.state")
local float = require("aichat.ui.float")
local split = require("aichat.ui.split")
local client = require("aichat.client")

local M = {}

function M.setup(opts)
	opts = cfg.setup(opts)
	local st = st_mod.get()
	st.provider = opts.provider
	st.conversation = opts.conversation

	-- Default keymaps
	vim.keymap.set("n", opts.keymaps.toggle_prompt, function()
		if not vim.api.nvim_win_is_valid(st.prompt_float.win) then
			float.open({})
		else
			vim.api.nvim_win_hide(st.prompt_float.win)
		end
	end, { desc = "Toggle AI prompt float" })

	vim.keymap.set("n", opts.keymaps.toggle_split, function()
		if not vim.api.nvim_win_is_valid(st.split.win) then
			split.open({})
		else
			vim.api.nvim_win_hide(st.split.win)
		end
	end, { desc = "Toggle AI split" })

	-- Command(s)
	vim.api.nvim_create_user_command("AichatState", function()
		print("[Aichat] state")
		print(vim.inspect(cfg.get()))
	end, {
		desc = "Print current chat state",
	})
end

function M.toggle_conversation_mode()
	local st = st_mod.get()
	st_mod.set_conversation(not st.conversation)
	print("[Aichat] conversation mode set to: " .. tostring(st.conversation))
end

-- public API
M.chat = client.chat
M.open_prompt = function()
	return float.open({})
end
M.open_split = function()
	return split.open({})
end

return M
