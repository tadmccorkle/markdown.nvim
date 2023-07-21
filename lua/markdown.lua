local api = vim.api
local ts = vim.treesitter

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
		(_ (inline) @inline)?) @li
]])
local list_item_minus_id = 1;
local list_item_star_id = 2;
local list_item_plus_id = 3;
local list_item_dot_id = 4;
local list_item_paren_id = 5;
local list_item_inline_id = 6;
local list_item_li_id = 7;

local ordered_list_query = ts.query.parse("markdown", [[
	(list
		(list_item [
			(list_marker_dot)
			(list_marker_parenthesis)
		])) @l
]])

-- 0-based row and col
local function find_innermost_match_containing(query, pos)
	local t = ts.get_parser(0, "markdown"):parse()[1]

	local match
	for _, m, _ in query:iter_matches(t:root(), 0, 0, -1) do
		for _, node in pairs(m) do
			local node_start_row, _, _, _ = node:range()
			if ts.node_contains(node, { pos[1], pos[2], pos[1], pos[2] }) then
				match = m
			elseif node_start_row > pos[1] then
				return match
			end
		end
	end
	return match
end

local function get_list_marker_for_match(match)
	local marker_id
	if match[list_item_minus_id] ~= nil then
		marker_id = list_item_minus_id
	elseif match[list_item_star_id] ~= nil then
		marker_id = list_item_star_id
	elseif match[list_item_plus_id] ~= nil then
		marker_id = list_item_plus_id
	elseif match[list_item_dot_id] ~= nil then
		marker_id = list_item_dot_id
	elseif match[list_item_paren_id] ~= nil then
		marker_id = list_item_paren_id
	end

	return marker_id, ts.get_node_text(match[marker_id], 0, nil)
end

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

local insert_loc = {}
insert_loc.above = 1
insert_loc.below = 2

local function insert_list_item(loc)
	local cursor = api.nvim_win_get_cursor(0) -- 1-based row, 0-based col
	local curr_row = cursor[1] - 1
	local curr_eol = vim.fn.charcol("$") - 1
	local match = find_innermost_match_containing(list_item_query, { curr_row, curr_eol })
	if match == nil then
		return
	end

	local marker_id, marker = get_list_marker_for_match(match)
	local mrow_start, mcol_start, _, _ = match[marker_id]:range()
	local indent = api.nvim_buf_get_text(0, mrow_start, 0, mrow_start, mcol_start, {})[1]
	local li_row_start, _, _, _ = match[list_item_li_id]:range()

	local new_row
	if loc == insert_loc.above then
		new_row = li_row_start
	elseif match[list_item_inline_id] ~= nil then
		local _, _, inline_end, _ = match[list_item_inline_id]:range()
		new_row = inline_end + 1
	else
		new_row = mrow_start + 1
	end

	api.nvim_buf_set_lines(0, new_row, new_row, true, { indent .. marker })

	if marker_id == list_item_dot_id or marker_id == list_item_paren_id then
		local list = find_innermost_match_containing(ordered_list_query, { curr_row, curr_eol })[1]
		reset_list_numbering(list)
	end

	new_row = new_row + 1
	api.nvim_win_set_cursor(0, { new_row, vim.fn.charcol({ new_row, "$" }) })
	if api.nvim_get_mode().mode == "n" then
		api.nvim_feedkeys("a", "n", true)
	end
end

local group = api.nvim_create_augroup("markdown.nvim", {})
local function handle_key_autocmd_opts(pattern)
	return {
		group = group,
		pattern = pattern,
		callback = function()
			vim.keymap.set({ "n", "i" }, "<M-l><M-o>", function()
				insert_list_item(insert_loc.below)
			end, { buffer = 0 })
			vim.keymap.set({ "n", "i" }, "<M-L><M-O>", function()
				insert_list_item(insert_loc.above)
			end, { buffer = 0 })
			vim.keymap.set({ "n", "i" }, "<M-l><M-n>", function()
				local t = ts.get_parser(0, "markdown"):parse()[1]
				for _, match, _ in ordered_list_query:iter_matches(t:root(), 0, 0, -1) do
					reset_list_numbering(match[1])
				end
			end, { buffer = 0 })
		end
	}
end

function M.setup()
	api.nvim_clear_autocmds({ group = group })
	api.nvim_create_autocmd("BufEnter", handle_key_autocmd_opts({ "*.md" }))
	api.nvim_create_autocmd("FileType", handle_key_autocmd_opts("markdown"))
end

return M
