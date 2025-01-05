local M = {}

---@class ScrollSyncConfig
---@field enabled boolean Whether to enable scroll sync on loaded
---@field reversed boolean Reverse sync order direction (default to left-to-right, top to bottom; true for opposite)
---@field hide_line_number "all"|"others"|"none" Control line number visibility in synchronized windows
---@field overlap_lines number Set number for overlapping lines for synchronized windows.
---@field scroll_options table Scrollbind options (see :h 'scrollopt')
---@field scroll_options.vertical boolean Enable vertical scroll synchronization
---@field scroll_options.horizontal boolean Enable horizontal scroll synchronization
---@field scroll_options.jump boolean Enable jump scroll synchronization
M.config = {
	enabled = false,
	reversed = false,
	hide_line_number = "others",
	overlap_lines = 0,
	scroll_options = {
		vertical = true, -- 'ver'
		horizontal = false, -- 'hor'
		jump = true, -- 'jump'
	},
	-- TODO: handle folds
}

local state = {
	sync_group = vim.api.nvim_create_augroup("ScrollSync", { clear = true }),
	enabled = false,
}

-- Update scrollopt based on configuration
local function update_scrollopt()
	local opts = {}
	if M.config.scroll_options.vertical then
		table.insert(opts, "ver")
	end
	if M.config.scroll_options.horizontal then
		table.insert(opts, "hor")
	end
	if M.config.scroll_options.jump then
		table.insert(opts, "jump")
	end
	vim.opt.scrollopt = table.concat(opts, ",")
end

-- Get windows displaying the same buffer, sorted by position
local function get_buffer_windows(buf)
	local all_wins = vim.api.nvim_list_wins()
	local buf_wins = {}
	-- Collect valid windows showing the target buffer
	for _, win in ipairs(all_wins) do
		if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
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

---Scrolls the specified window to a given line number while respecting scrolloff settings
---@param win number The window handle to scroll
---@param new_line number The target line number to scroll to
local function win_scroll_to_line(win, new_line)
	if not vim.api.nvim_win_is_valid(win) then
		return
	end

	vim.api.nvim_win_call(win, function()
		vim.cmd(string.format("normal! %dG zt", new_line))
	end)
end

---Disables scrollbind option for the specified window
---@param win number The window handle where scrollbind should be disabled
local function disable_scrollbind(win)
	if vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_set_option_value("scrollbind", false, { win = win })
	end
end

---Synchronizes scroll positions and settings across multiple windows of the same buffer
---@param buf number Buffer handle to synchronize
---@return nil
local function sync_buffer_windows(buf)
	if not state.enabled then
		return
	end

	local all_wins = vim.api.nvim_tabpage_list_wins(0)
	for _, win in ipairs(all_wins) do
		disable_scrollbind(win)
	end

	local wins = get_buffer_windows(buf)
	if #wins <= 1 then
		return
	end

	local base_line = vim.fn.line("w0", wins[1])
	local buf_line_count = vim.api.nvim_buf_line_count(buf)
	local hide_line_number = M.config.hide_line_number
	local line_number_threshold = hide_line_number == "all" and 0 or hide_line_number == "none" and #wins + 1 or 1

	for i = 2, #wins do
		local win = wins[i]
		local win_height = vim.fn.winheight(win)
		local scrolloff = vim.api.nvim_get_option_value("scrolloff", { win = win })

		local overlap_lines = M.config.overlap_lines
		scrolloff = scrolloff == -1 and vim.go.scrolloff or scrolloff -- Get window-local scrolloff value, fallback to global if not set

		local new_line = base_line + win_height * (i - 1) + scrolloff - overlap_lines
		new_line = math.min(math.max(new_line, 1 + scrolloff), buf_line_count - scrolloff) -- Bound new_line within valid range

		win_scroll_to_line(win, new_line)
		vim.api.nvim_set_option_value("scrollbind", true, { win = win })

		if i > line_number_threshold then
			vim.api.nvim_set_option_value("number", false, { win = win })
		end
	end

	-- Enable scrollbind for the first window
	vim.api.nvim_set_option_value("scrollbind", true, { win = wins[1] })
end

function M.enable()
	state.enabled = true
	update_scrollopt()

	-- Sync current buffer's windows
	local current_buf = vim.api.nvim_get_current_buf()
	sync_buffer_windows(current_buf)
end

function M.disable()
	state.enabled = false

	-- Disable scrollbind for all windows
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		disable_scrollbind(win)
	end
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
	-- Merge user configuration with defaults
	if opts then
		M.config = vim.tbl_deep_extend("force", M.config, opts)
	end

	-- Create user commands
	vim.api.nvim_create_user_command("ScrollSyncEnable", M.enable, {
		desc = "Enable scroll synchronization",
	})
	vim.api.nvim_create_user_command("ScrollSyncDisable", M.disable, {
		desc = "Disable scroll synchronization",
	})
	vim.api.nvim_create_user_command("ScrollSyncToggle", M.toggle, {
		desc = "Toggle scroll synchronization",
	})

	-- Initial scrollopt setup
	update_scrollopt()

	state.prev_buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_create_autocmd({ "WinEnter", "BufWinEnter" }, {
		group = state.sync_group,
		callback = function()
			if state.enabled then
				-- Sync windows if entering a new buffer
				local curr_buf = vim.api.nvim_get_current_buf()
				if curr_buf ~= state.prev_buf then
					sync_buffer_windows(curr_buf)
					state.prev_buf = curr_buf
				end
			end
		end,
	})

	-- TODO: Watch for scrolloff changes
	-- vim.api.nvim_create_autocmd("OptionSet", {
	-- 	group = state.sync_group,
	-- 	pattern = "scrolloff",
	-- 	callback = function()
	-- 		-- Recalculate default offset if using automatic calculation
	-- 		if not M.config.offset.lines then
	-- 			M.config.offset.lines = calculate_default_offset()
	-- 		end
	-- 	end,
	-- })

	-- Enable by default if configured
	if M.config.enabled then
		M.enable()
	end
end

return M
