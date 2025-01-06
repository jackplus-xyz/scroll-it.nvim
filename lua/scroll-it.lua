local M = {}

local state = {
	sync_group = vim.api.nvim_create_augroup("ScrollSync", { clear = true }),
	enabled = false,
	curr_win = nil,
}

M.config = {
	enabled = false,
	reversed = false,
	hide_line_number = "others",
	overlap_lines = 0,
}

local function is_valid_win(win)
	return vim.api.nvim_win_is_valid(win) and win ~= nil
end

local function is_valid_buf(buf)
	return vim.api.nvim_buf_is_valid(buf) and buf ~= nil
end

local function buf_get_sorted_wins(buf)
	local all_wins = vim.api.nvim_list_wins()
	local buf_wins = {}
	-- Collect valid windows showing the target buffer
	for _, win in ipairs(all_wins) do
		if is_valid_win(win) and vim.api.nvim_win_get_buf(win) == buf then
			table.insert(buf_wins, win)
		end
	end

	local reversed = M.config.reversed
	-- Sort windows based on position (left to right, top to bottom)
	table.sort(buf_wins, function(a, b)
		local pos_a = vim.api.nvim_win_get_position(a)
		local pos_b = vim.api.nvim_win_get_position(b)

		if pos_a[1] ~= pos_b[1] then
			return reversed and pos_a[1] > pos_b[1] or pos_a[1] < pos_b[1]
		end
		return reversed and pos_a[2] > pos_b[2] or pos_a[2] < pos_b[2]
	end)

	return buf_wins
end

local function win_scroll_to_line(win, line, dir)
	dir = dir or "top"
	if not is_valid_win(win) then
		return
	end

	vim.api.nvim_win_call(win, function()
		if dir == "top" then
			vim.cmd(string.format("normal! %dG zt", line))
		else
			vim.cmd(string.format("normal! %dG zb", line))
		end
	end)
end

local function buf_update_wins(buf)
	if not state.enabled then
		return
	end

	if not is_valid_buf(buf) then
		return
	end

	local sorted_wins = buf_get_sorted_wins(buf)
	if #sorted_wins <= 1 then
		return
	end
	local curr_win = vim.api.nvim_get_current_win()
	local curr_win_idx = 0

	-- Find current window index
	for i, win in ipairs(sorted_wins) do
		if win == curr_win then
			curr_win_idx = i
			break
		end
	end

	-- Config opts
	local overlap_lines = M.config.overlap_lines
	local hide_line_number = M.config.hide_line_number

	for i, win in ipairs(sorted_wins) do
		if win ~= curr_win then
			local scrolloff = vim.api.nvim_get_option_value("scrolloff", { win = win })
			scrolloff = scrolloff == -1 and vim.go.scrolloff or scrolloff

			if curr_win_idx == 1 then
				-- Current window is first, scroll all windows down
				local new_line = vim.fn.line("w$", sorted_wins[i - 1]) + 1 + scrolloff - overlap_lines
				win_scroll_to_line(win, new_line, "top")
			elseif curr_win_idx == #sorted_wins then
				-- Current window is last, scroll all windows up
				local new_line = vim.fn.line("w0", sorted_wins[i + 1]) - 1 - scrolloff + overlap_lines
				win_scroll_to_line(win, new_line, "bottom")
			else
				-- Current window is in middle, scroll windows above and below accordingly
				if i < curr_win_idx then
					local new_line = vim.fn.line("w0", curr_win) - 1 - scrolloff + overlap_lines
					win_scroll_to_line(win, new_line, "bottom")
				else
					local new_line = vim.fn.line("w$", curr_win) + 1 + scrolloff - overlap_lines
					win_scroll_to_line(win, new_line, "top")
				end
			end
		end

		if hide_line_number == "others" then
			vim.api.nvim_set_option_value("number", win == curr_win, { win = win })
		else
			vim.api.nvim_set_option_value("number", hide_line_number == "none", { win = win })
		end
	end
end

function M.enable()
	state.enabled = true

	local current_buf = vim.api.nvim_get_current_buf()
	buf_update_wins(current_buf)
end

function M.disable()
	state.enabled = false
end

function M.toggle()
	if state.enabled then
		M.disable()
		vim.notify("**Scroll Sync** disabled")
	else
		M.enable()
		vim.notify("**Scroll Sync** enabled")
	end
end

function M.setup(opts)
	if opts then
		M.config = vim.tbl_deep_extend("force", M.config, opts)
	end

	-- Create commands (unchanged)
	vim.api.nvim_create_user_command("ScrollItEnable", M.enable, {
		desc = "Enable scroll synchronization",
	})
	vim.api.nvim_create_user_command("ScrollItDisable", M.disable, {
		desc = "Disable scroll synchronization",
	})
	vim.api.nvim_create_user_command("ScrollItToggle", M.toggle, {
		desc = "Toggle scroll synchronization",
	})

	local sync_group = state.sync_group
	vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter", "WinScrolled", "WinNew", "WinClosed" }, {
		group = sync_group,
		callback = function()
			if state.enabled then
				local curr_buf = vim.api.nvim_get_current_buf()
				buf_update_wins(curr_buf)
			end
		end,
	})

	if M.config.enabled then
		M.enable()
	end
end

return M
