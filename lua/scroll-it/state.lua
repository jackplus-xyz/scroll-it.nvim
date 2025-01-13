local M = {}

function M.setup()
	M.sync_group = vim.api.nvim_create_augroup("ScrollSync", { clear = true })
	M.scroll_group = vim.api.nvim_create_augroup("ScrollSyncScroll", { clear = true })
	M.enabled = false
	M.original_settings = {
		number = vim.api.nvim_get_option_value("number", { scope = "global" }),
		relativenumber = vim.api.nvim_get_option_value("relativenumber", { scope = "global" }),
	}
end

return M
