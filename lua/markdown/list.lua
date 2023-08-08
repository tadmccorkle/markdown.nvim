local api = vim.api
local ts = vim.treesitter

local md_ts = MDR("markdown.treesitter")

local M = {}

local list_item_query = ts.query.parse("markdown", [[
	(list_item
		[
		 (list_marker_minus) @minus
		 (list_marker_star) @star
		 (list_marker_plus) @plus
		 (list_marker_dot) @dot
		 (list_marker_parenthesis) @paren
		]
		[
		 (task_list_marker_checked)
		 (task_list_marker_unchecked)
		]? @taskmarker
		(_ (inline) @inline)?) @li
]])
local LIST_ITEM_MINUS_ID = 1;
local LIST_ITEM_STAR_ID = 2;
local LIST_ITEM_PLUS_ID = 3;
local LIST_ITEM_DOT_ID = 4;
local LIST_ITEM_PAREN_ID = 5;
local LIST_ITEM_TASK_MARKER_ID = 6;
local LIST_ITEM_INLINE_ID = 7;
local LIST_ITEM_LI_ID = 8;

local ordered_list_query = ts.query.parse("markdown", [[
	(list
		(list_item [
			(list_marker_dot)
			(list_marker_parenthesis)
		])) @l
]])

---@param match table<integer, TSNode>
---@return integer, string
local function get_list_marker_for_match(match)
	local marker_id
	if match[LIST_ITEM_MINUS_ID] ~= nil then
		marker_id = LIST_ITEM_MINUS_ID
	elseif match[LIST_ITEM_STAR_ID] ~= nil then
		marker_id = LIST_ITEM_STAR_ID
	elseif match[LIST_ITEM_PLUS_ID] ~= nil then
		marker_id = LIST_ITEM_PLUS_ID
	elseif match[LIST_ITEM_DOT_ID] ~= nil then
		marker_id = LIST_ITEM_DOT_ID
	elseif match[LIST_ITEM_PAREN_ID] ~= nil then
		marker_id = LIST_ITEM_PAREN_ID
	end

	return marker_id, ts.get_node_text(match[marker_id], 0, nil)
end

---@param list TSNode
local function reset_list_numbering(list)
	local num = 1
	for list_item in list:iter_children() do
		local text = ts.get_node_text(list_item, 0, nil)
		local marker_digits = text:match("(%d+)")
		local row, col, _, _ = list_item:range()
		local num_str = tostring(num)
		if marker_digits ~= num_str then
			api.nvim_buf_set_text(0, row, col, row, col + #marker_digits, { num_str })
		end
		num = num + 1
	end
end

--- Resets list numbering in the current buffer.
function M.reset_list_numbering()
	local t = ts.get_parser(0, "markdown"):parse()[1]
	for _, match, _ in ordered_list_query:iter_matches(t:root(), 0, 0, -1) do
		reset_list_numbering(match[1])
	end
end

local INSERT_LOC = {
	ABOVE = 1,
	BELOW = 2,
}

---@param loc integer
local function insert_list_item(loc)
	local t = ts.get_parser(0, "markdown"):parse()[1]

	local cursor = api.nvim_win_get_cursor(0) -- 1-based row, 0-based col
	local curr_row = cursor[1] - 1
	local curr_eol = vim.fn.charcol("$") - 1
	local match = md_ts.find_innermost_match_containing(t, list_item_query, { curr_row, curr_eol })
	if match == nil then
		return
	end

	local marker_id, marker = get_list_marker_for_match(match)
	local mrow_start, mcol_start, _, _ = match[marker_id]:range()
	local indent = api.nvim_buf_get_text(0, mrow_start, 0, mrow_start, mcol_start, {})[1]
	local li_row_start, _, _, _ = match[LIST_ITEM_LI_ID]:range()

	local new_row
	if loc == INSERT_LOC.ABOVE then
		new_row = li_row_start
	elseif match[LIST_ITEM_INLINE_ID] ~= nil then
		local _, _, inline_end, _ = match[LIST_ITEM_INLINE_ID]:range()
		new_row = inline_end + 1
	else
		new_row = mrow_start + 1
	end

	local task_marker = match[LIST_ITEM_TASK_MARKER_ID] and "[ ] " or ""

	api.nvim_buf_set_lines(0, new_row, new_row, true, { indent .. marker .. task_marker })

	if marker_id == LIST_ITEM_DOT_ID or marker_id == LIST_ITEM_PAREN_ID then
		local t_new = ts.get_parser(0, "markdown"):parse()[1]
		local list = md_ts.find_innermost_match_containing(t_new, ordered_list_query,
					{ curr_row, curr_eol })
				[1]
		reset_list_numbering(list)
	end

	new_row = new_row + 1
	api.nvim_win_set_cursor(0, { new_row, vim.fn.charcol({ new_row, "$" }) })
	if api.nvim_get_mode().mode == "n" then
		api.nvim_feedkeys("a", "n", true)
	end
end

--- Inserts a list item above the cursor in the current buffer.
function M.insert_list_item_above()
	insert_list_item(INSERT_LOC.ABOVE)
end

--- Inserts a list item below the cursor in the current buffer.
function M.insert_list_item_below()
	insert_list_item(INSERT_LOC.BELOW)
end

return M
