local api = vim.api
local ts = vim.treesitter

local md_ts = require("markdown.treesitter")
local util = require("markdown.util")

local M = {}

local LIST_TYPE = "list"
local LIST_ITEM_TYPE = "list_item"
local LIST_MARKER_DOT_TYPE = "list_marker_dot"
local LIST_MARKER_PAREN_TYPE = "list_marker_parenthesis"
local TASK_MARKER_CHECKED_TYPE = "task_list_marker_checked"
local TASK_MARKER_UNCHECKED_TYPE = "task_list_marker_unchecked"
local PARAGRAPH_TYPE = "paragraph"
local INLINE_TYPE = "inline"

local ordered_list_query = ts.query.parse("markdown", [[
	(list
		(list_item [
			(list_marker_dot)
			(list_marker_parenthesis)
		])) @l
]])
--
---@param node TSNode
---@return boolean
local function is_list_item(node)
	return node:type() == LIST_ITEM_TYPE
end

---@param node TSNode
---@return boolean
local function is_list(node)
	return node:type() == LIST_TYPE
end

---@param list_item TSNode
---@param change integer
local function adjust_child_indent(list_item, change)
	local li_row = list_item:start()
	for child in list_item:iter_children() do
		local start_row, start_col, end_row, _ = child:range()
		if start_row ~= li_row and start_col ~= 0 then
			-- final row is a block continuation and shouldn't be changed
			for row = start_row, end_row - 1, 1 do
				if change < 0 then
					util.delete_text(row, 0, math.abs(change))
				else
					util.insert_text(row, 0, string.rep(" ", change))
				end
			end
		end
	end
end

---@param list_item TSNode
local function set_list_item_num(list_item, num)
	local text = ts.get_node_text(list_item, 0, nil)
	local marker_digits = text:match("(%d+)")
	local row, col = list_item:start()
	local num_str = tostring(num)
	if marker_digits ~= num_str then
		local marker_digit_len = #marker_digits
		util.replace_text(row, col, marker_digit_len, num_str)

		local child_indent_change = #num_str - marker_digit_len
		if child_indent_change ~= 0 then
			adjust_child_indent(list_item, child_indent_change)
		end
	end
end

---@param list TSNode
local function reset_list_numbering(list)
	local num = 1
	for list_item in list:iter_children() do
		if list_item:named() then
			set_list_item_num(list_item, num)
			num = num + 1
		end
	end
end

--- Resets list numbering in the current buffer.
---@param start_row integer Zero-based start row
---@param end_row integer Zero-based end row
---
--- Specify start = 0 and end = -1 to reset list numbering
--- for all lists in the current buffer.
function M.reset_list_numbering(start_row, end_row)
	if end_row >= 0 then
		end_row = end_row + 1
	end

	local t = ts.get_parser(0, "markdown"):parse()[1]
	for _, match, _ in ordered_list_query:iter_matches(t:root(), 0, start_row, end_row, { all = true }) do
		local list = md_ts.single_node_from_match(match, 1)
		reset_list_numbering(list)
	end
end

---@param list_item TSNode
local function get_last_list_item_inline(list_item)
	for i = list_item:named_child_count() - 1, 0, -1 do
		local child = list_item:named_child(i) --[[@as TSNode]]
		if child:type() == PARAGRAPH_TYPE then
			for j = child:named_child_count() - 1, 0, -1 do
				if child:named_child(j):type() == INLINE_TYPE then
					return child:named_child(j)
				end
			end
		end
	end
end

---@return integer row, integer col
local function get_curr_eol_pos()
	local curr_row = util.get_cursor()
	local curr_eol = vim.fn.charcol("$") - 1
	return curr_row, curr_eol
end

---@enum rel_pos relative position
local REL_POS = {
	above = 1,
	below = 2,
}

---@param loc rel_pos
local function insert_list_item(loc)
	local curr_row, curr_eol = get_curr_eol_pos()

	ts.get_parser(0, "markdown"):parse()
	local list_item = md_ts.find_node(is_list_item, { pos = { curr_row, curr_eol } })
	if list_item == nil then
		return
	end

	local marker = list_item:named_child(0)
	if marker == nil then
		return
	end

	local marker_type = marker:type()
	local marker_row, marker_col = marker:start()

	---@type TSNode|nil
	local task_marker = marker:next_named_sibling()
	if
		task_marker ~= nil
		and task_marker:type() ~= TASK_MARKER_CHECKED_TYPE
		and task_marker:type() ~= TASK_MARKER_UNCHECKED_TYPE
	then
		task_marker = nil
	end

	local new_row
	if loc == REL_POS.above then
		new_row = list_item:start()
	else
		local inline = get_last_list_item_inline(list_item)
		if inline ~= nil then
			local inline_end = inline:end_()
			new_row = inline_end + 1
		else
			new_row = marker_row + 1
		end
	end

	local indent = api.nvim_buf_get_text(0, marker_row, 0, marker_row, marker_col, {})[1]
	local marker_txt = ts.get_node_text(marker, 0, nil)
	local task_marker_txt = task_marker and "[ ] " or ""
	api.nvim_buf_set_lines(0, new_row, new_row, true, { indent .. marker_txt .. task_marker_txt })

	if marker_type == LIST_MARKER_DOT_TYPE or marker_type == LIST_MARKER_PAREN_TYPE then
		ts.get_parser(0, "markdown"):parse()
		local list = md_ts.find_node(is_list, { pos = { curr_row, curr_eol } })
		if list ~= nil then
			reset_list_numbering(list)
		end
	end

	new_row = new_row + 1
	api.nvim_win_set_cursor(0, { new_row, vim.fn.charcol({ new_row, "$" }) })
	vim.cmd("startinsert!")
end

--- Inserts a list item above the cursor in the current buffer.
function M.insert_list_item_above()
	insert_list_item(REL_POS.above)
end

--- Inserts a list item below the cursor in the current buffer.
function M.insert_list_item_below()
	insert_list_item(REL_POS.below)
end

---@param node TSNode
---@return boolean
local function is_task_list_item(node)
	if node:type() ~= LIST_ITEM_TYPE then
		return false
	end

	local task_marker = node:named_child(1)
	if task_marker == nil then
		return false
	end

	local tm_type = task_marker:type()
	return tm_type == TASK_MARKER_CHECKED_TYPE
		or tm_type == TASK_MARKER_UNCHECKED_TYPE
end

--- Toggles list item task markers.
---@param start_row integer Zero-based start row
---@param end_row integer Zero-based end row
function M.toggle_task(start_row, end_row)
	ts.get_parser(0, "markdown"):parse()
	local task_markers = {}

	local last_node
	for row = start_row, end_row, 1 do
		local eol = vim.fn.charcol({ row + 1, "$" }) - 1
		local node = md_ts.find_node(is_task_list_item, { pos = { row, eol } })
		if node ~= nil and node ~= last_node then
			table.insert(task_markers, node:named_child(1))
			last_node = node
		end
	end

	local checked = false
	for i = 1, #task_markers, 1 do
		if task_markers[i]:type() == TASK_MARKER_UNCHECKED_TYPE then
			local row, start_col, _, end_col = task_markers[i]:range()
			util.replace_text(row, start_col, end_col - start_col + 1, "[x] ")
			checked = true
		end
	end

	if not checked then
		for i = 1, #task_markers, 1 do
			local row, start_col, _, end_col = task_markers[i]:range()
			util.replace_text(row, start_col, end_col - start_col + 1, "[ ] ")
		end
	end
end

return M
