local M = {}

M.defaults = {
	enabled = false,
	reversed = false,
	hide_line_number = "others",
	overlap_lines = 0,
}

M.options = {}

function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
