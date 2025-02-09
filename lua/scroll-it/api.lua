local Utils = require("scroll-it.utils")
local State = require("scroll-it.state")
local M = {}

function M.enable()
	State.enabled = true
	Utils.sync_wins()
end

function M.disable()
	if State.enabled then
		local original_settings = State.original_settings
		Utils.restore_wins_settings(original_settings)
		State.enabled = false
	end
	if State.scroll_timer then
		State.scroll_timer:stop()
		State.scroll_timer = nil
	end
end

function M.toggle()
	if State.enabled then
		M.disable()
	else
		M.enable()
	end
	vim.notify(string.format("**ScrollIt** %s", State.enabled and "enabled" or "disabled"))
end

return M
