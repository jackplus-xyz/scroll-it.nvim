local Utils = require("scroll-it.utils")
local State = require("scroll-it.state")
local Api = require("scroll-it.api")

local M = {}

local defaults = {
	enabled = false,
	reversed = false,
	hide_line_number = "others",
	overlap_lines = 0,
}

function M.setup(options)
	M.options = vim.tbl_deep_extend("force", defaults, options or {})

	State.setup()

	vim.api.nvim_create_user_command("ScrollItEnable", Api.enable, { desc = "Enable scroll synchronization" })
	vim.api.nvim_create_user_command("ScrollItDisable", Api.disable, { desc = "Disable scroll synchronization" })
	vim.api.nvim_create_user_command("ScrollItToggle", Api.toggle, { desc = "Disable scroll synchronization" })

	vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter", "WinNew", "WinClosed" }, {
		group = State.sync_group,
		callback = function()
			if State.enabled then
				Api.enable()
			end
		end,
	})

	vim.api.nvim_create_autocmd("WinScrolled", {
		group = State.scroll_group,
		callback = Utils.handle_scroll,
	})

	if M.options.enabled then
		Api.enable()
	end
end

return M
