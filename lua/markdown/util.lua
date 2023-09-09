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
	return s:gsub(" ", "-"):lower()
end

---@return boolean, string|nil
function M.try_get_char_input()
	local ok, char = pcall(vim.fn.getcharstr)
	if not ok or char == "\27" then
		return false, nil
	end
	return true, char
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

--- Gets the start and end lines from user command range arguments, defaulting to the cursor line in
--- the current buffer if the user command has no range specified.
---@param opts table User command arguments table
---@return integer start_row, integer end_row
---
---@see nvim_create_user_command
function M.get_user_command_range(opts)
	if opts.range == 0 then
		local row = api.nvim_win_get_cursor(0)[1] - 1 -- 1-based row, 0-based col
		return row, row
	end
	return opts.line1 - 1, opts.line2
end

return M
