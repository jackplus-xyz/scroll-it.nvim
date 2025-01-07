if vim.fn.has("nvim-0.7.0") == 0 then
	vim.api.nvim_err_writeln("ScrollIt requires at least nvim-0.7.0")
	return
end

-- Prevent loading more than once
if vim.g.loaded_scroll_it == 1 then
	return
end
vim.g.loaded_scroll_it = 1

-- Setup with empty defaults
require("scroll-it").setup()
