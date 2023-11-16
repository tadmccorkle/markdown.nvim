local api = vim.api

local M = {}

--- Removes comments and new lines.
---@param s string
---@return string
function M.sanitize(s)
	local sanitized, _ = s:gsub("(%s-)\n(%s*)", " ")
		:gsub("<!--(.-)-->", "")
		:gsub("^%s*(.-)%s*$", "%1")
	return sanitized
end

---@param s string
---@return string
function M.slugify(s)
	return s:gsub("%s", "-")
		:gsub("[^%w_-]", "")
		:lower()
end

---@return boolean, string|nil
function M.try_get_char_input()
	local ok, char = pcall(vim.fn.getcharstr)
	if not ok or char == "\27" then
		return false, nil
	end
	return true, char
end

--- Gets text from a single line in the current buffer.
---@param row integer zero-based row
---@param col integer zero-based column
---@param len integer number of characters to get
function M.get_text(row, col, len)
	return api.nvim_buf_get_text(0, row, col, row, col + len, {})[1]
end

--- Inserts text on a single line in the current buffer.
---@param row integer zero-based row for insertion
---@param col integer zero-based column for insertion
---@param txt string text to insert
function M.insert_text(row, col, txt)
	api.nvim_buf_set_text(0, row, col, row, col, { txt })
end

--- Deletes text on a single line from the current buffer.
---@param row integer zero-based row for deletion
---@param col integer zero-based column for deletion
---@param len integer number of characters to delete
function M.delete_text(row, col, len)
	api.nvim_buf_set_text(0, row, col, row, col + len, { "" })
end

--- Replaces text on a single line in the current buffer.
---@param row integer zero-based row for replacement
---@param col integer zero-based column for replacement
---@param len integer number of characters to replace
---@param txt string replacement text
function M.replace_text(row, col, len, txt)
	api.nvim_buf_set_text(0, row, col, row, col + len, { txt })
end

--- Gets the overlap of two ranges that are known to overlap.
---@param range1 R4
---@param range2 R4
---@return R4
function M.get_overlapping_range(range1, range2)
	local r1, r2, r3, r4
	if range1[1] < range2[1] then
		r1 = range2[1]
		r2 = range2[2]
	elseif range1[1] > range2[1] then
		r1 = range1[1]
		r2 = range1[2]
	else
		r1 = range1[1]
		r2 = math.max(range1[2], range2[2])
	end
	if range1[3] > range2[3] then
		r3 = range2[3]
		r4 = range2[4]
	elseif range1[3] < range2[3] then
		r3 = range1[3]
		r4 = range1[4]
	else
		r3 = range1[3]
		r4 = math.min(range1[4], range2[4])
	end

	return { r1, r2, r3, r4 }
end

--- Determines if a given range contains a given row/column position.
---@param range R4
---@param pos Position
---@return boolean
function M.range_contains_position(range, pos)
	return (range[1] < pos[1] or (range[1] == pos[1] and range[2] <= pos[2]))
		and (range[3] > pos[1] or (range[3] == pos[1] and range[4] >= pos[2]))
end

---@param a_row integer
---@param a_col integer
---@param b_row integer
---@param b_col integer
---@return integer
--- 1: a > b
--- 0: a == b
--- -1: a < b
local function cmp_pos(a_row, a_col, b_row, b_col)
	if a_row == b_row then
		if a_col > b_col then
			return 1
		elseif a_col < b_col then
			return -1
		else
			return 0
		end
	elseif a_row > b_row then
		return 1
	end
	return -1
end

--- Determines if two ranges overlap.
---@param r1 R4
---@param r2 R4
---@return boolean
function M.ranges_overlap(r1, r2)
	-- r1 is above r2
	if cmp_pos(r1[3], r1[4], r2[1], r2[2]) ~= 1 then
		return false
	end

	-- r1 is below r2
	if cmp_pos(r1[1], r1[2], r2[3], r2[4]) ~= -1 then
		return false
	end

	return true
end

--- Gets the zero-based start and end lines from user command range arguments, defaulting to the
--- cursor line in the current buffer if the user command has no range specified.
---@param opts table User command arguments table
---@return integer start_row, integer end_row
---
---@see nvim_create_user_command
function M.get_user_command_range(opts)
	if opts.range == 0 then
		local row = api.nvim_win_get_cursor(0)[1] - 1 -- 1-based row, 0-based col
		return row, row
	end

	return opts.line1 - 1, opts.line2 - 1
end

--- Gets a "tab" for the current buffer based on buffer options.
---@return string
function M.get_tab_str()
	if api.nvim_buf_get_option(0, "expandtab") then
		return string.rep(" ", api.nvim_buf_get_option(0, "tabstop"))
	end
	return "\t"
end

--- Gets the range corresponding to the last visual selection.
---@return R4
function M.get_visual_range()
	local s, e = api.nvim_buf_get_mark(0, "<"), api.nvim_buf_get_mark(0, ">")
	if vim.o.selection == "exclusive" then
		e[2] = e[2] - 1
	end
	e[2] = math.min(e[2] + 1, vim.fn.charcol({ e[1], "$" }) - 1)
	s[1] = s[1] - 1
	e[1] = e[1] - 1

	return { s[1], s[2], e[1], e[2] }
end

--- Gets the range corresponding to the last vim motion.
---@param motion string
---@return R4
function M.get_motion_range(motion)
	local s, e = api.nvim_buf_get_mark(0, "["), api.nvim_buf_get_mark(0, "]")
	if motion == "line" then
		s[2] = 0
		e[2] = vim.fn.charcol({ e[1], "$" }) - 1
	else
		e[2] = e[2] + 1
	end
	s[1] = s[1] - 1
	e[1] = e[1] - 1

	return { s[1], s[2], e[1], e[2] }
end

return M
