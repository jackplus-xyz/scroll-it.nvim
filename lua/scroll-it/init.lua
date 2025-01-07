local M = {}
M.config = require("scroll-it.config")

local state = {
	sync_group = vim.api.nvim_create_augroup("ScrollSync", { clear = true }),
	scroll_group = vim.api.nvim_create_augroup("ScrollSyncScroll", { clear = true }),
	enabled = false,
	buf = {},
	original_settings = nil,
}

local function is_valid_win(win)
	return win and vim.api.nvim_win_is_valid(win)
end

local function is_valid_buf(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

local function buf_get_sorted_wins(buf)
	local wins = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if is_valid_win(win) and vim.api.nvim_win_get_buf(win) == buf then
			local pos = vim.api.nvim_win_get_position(win)
			wins[#wins + 1] = {
				win = win,
				row = pos[1],
				col = pos[2],
			}
		end
	end

	table.sort(wins, function(a, b)
		return a.row == b.row and a.col < b.col or a.row < b.row
	end)

	-- Extract just the window handles
	local result = {}
	for i, entry in ipairs(wins) do
		result[i] = entry.win
	end
	return result
end

local function get_base_line(win, position)
	return vim.fn.line(position == "top" and "w0" or "w$", win)
end

local function win_scroll_to_line(win, line, direction)
	if not is_valid_win(win) then
		return
	end

	vim.api.nvim_win_call(win, function()
		if direction == "top" then
			vim.cmd(string.format("normal! %dG zt", line))
		else
			vim.cmd(string.format("normal! %dG zb", line))
		end
	end)
end

local function set_line_number(win, is_set_line_number)
	vim.api.nvim_set_option_value("number", is_set_line_number, { win = win })
	vim.api.nvim_set_option_value("relativenumber", is_set_line_number, { win = win })
end

local function align_wins(wins, start_idx, end_idx)
	local iter_dir = end_idx > start_idx and 1 or -1
	local start = start_idx
	local finish = end_idx

	while start ~= finish + iter_dir do
		local win = wins[start]
		local scrolloff = vim.api.nvim_get_option_value("scrolloff", { win = win })
		scrolloff = scrolloff == -1 and vim.go.scrolloff or scrolloff
		local offset = 1 + scrolloff - M.config.options.overlap_lines

		if start ~= start_idx then
			local ref_win = wins[start - iter_dir]
			if M.config.options.reversed then
				local new_line = get_base_line(ref_win, iter_dir > 0 and "top" or "bottom")
					+ (iter_dir > 0 and -offset or offset)
				win_scroll_to_line(win, new_line, iter_dir > 0 and "bottom" or "top")
			else
				local new_line = get_base_line(ref_win, iter_dir > 0 and "bottom" or "top")
					+ (iter_dir > 0 and offset or -offset)
				win_scroll_to_line(win, new_line, iter_dir > 0 and "top" or "bottom")
			end
		end

		local is_set_line_number = M.config.options.hide_line_number == "all"
		if M.config.options.hide_line_number == "others" and start == start_idx then
			is_set_line_number = true
		end

		set_line_number(win, is_set_line_number)

		start = start + iter_dir
	end
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
	local curr_win_idx = 1
	for i, win in ipairs(sorted_wins) do
		if win == curr_win then
			curr_win_idx = i
			break
		end
	end

	state.buf.wins = sorted_wins
	state.buf.curr_win_idx = curr_win_idx

	local last_idx = #sorted_wins
	if curr_win_idx == 1 or curr_win_idx == last_idx then
		if M.config.options.reversed then
			if curr_win_idx == last_idx then
				align_wins(sorted_wins, last_idx, 1)
			else
				align_wins(sorted_wins, 1, last_idx)
			end
		else
			if curr_win_idx == 1 then
				align_wins(sorted_wins, 1, last_idx)
			else
				align_wins(sorted_wins, last_idx, 1)
			end
		end
	else
		align_wins(sorted_wins, curr_win_idx, last_idx)
		align_wins(sorted_wins, curr_win_idx, 1)
	end
end

local function handle_scroll()
	if state.scroll_timer then
		state.scroll_timer:stop()
	end

	state.scroll_timer = vim.defer_fn(function()
		if state.enabled then
			local curr_buf = vim.api.nvim_get_current_buf()
			if is_valid_buf(curr_buf) then
				local sorted_wins = buf_get_sorted_wins(curr_buf)
				if #sorted_wins > 1 then
					local curr_win = vim.api.nvim_get_current_win()
					-- Only update if we're in a window showing the current buffer
					for _, win in ipairs(sorted_wins) do
						if win == curr_win then
							buf_update_wins(curr_buf)
							break
						end
					end
				end
			end
		end
		state.scroll_timer = nil
	end, 16) -- Debounce time of ~1 frame (60fps)
end

function M.enable()
	state.enabled = true
	buf_update_wins(vim.api.nvim_get_current_buf())
end

function M.disable()
	state.enabled = false
	if state.scroll_timer then
		state.scroll_timer:stop()
		state.scroll_timer = nil
	end

	if state.original_settings then
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if is_valid_win(win) then
				vim.api.nvim_set_option_value("number", state.original_settings.number, { win = win })
				vim.api.nvim_set_option_value("relativenumber", state.original_settings.relativenumber, { win = win })
			end
		end
	end
end

function M.toggle()
	if state.enabled then
		M.disable()
	else
		M.enable()
	end
	vim.notify(string.format("**Scroll Sync** %s", state.enabled and "enabled" or "disabled"))
end

function M.setup(opts)
	state.original_settings = {
		number = vim.o.number,
		relativenumber = vim.o.relativenumber,
	}
	M.config.setup(opts)

	local commands = {
		ScrollItEnable = { M.enable, "Enable scroll synchronization" },
		ScrollItDisable = { M.disable, "Disable scroll synchronization" },
		ScrollItToggle = { M.toggle, "Toggle scroll synchronization" },
	}

	for name, cmd in pairs(commands) do
		vim.api.nvim_create_user_command(name, cmd[1], { desc = cmd[2] })
	end

	vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter", "WinNew", "WinClosed" }, {
		group = state.sync_group,
		callback = function()
			if state.enabled then
				buf_update_wins(vim.api.nvim_get_current_buf())
			end
		end,
	})

	vim.api.nvim_create_autocmd("WinScrolled", {
		group = state.scroll_group,
		callback = handle_scroll,
	})

	if M.config.options.enabled then
		vim.defer_fn(M.enable, 100)
	end
end

return M
