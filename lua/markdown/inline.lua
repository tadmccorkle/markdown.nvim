local api = vim.api
local ts = vim.treesitter

local config = require("markdown.config")
local md_ts = require("markdown.treesitter")
local notify = require("markdown.notify")
local util = require("markdown.util")

local M = {}

local inline_query = ts.query.parse("markdown", "(inline) @inline")

---@param etype string
---@return vim.treesitter.Query
local function get_emphasis_query(etype)
	return ts.query.parse("markdown_inline", "(" .. etype .. ") @e")
end

local EMPHASIS_TYPE = "emphasis"
local STRONG_TYPE = "strong_emphasis"
local STRIKETHROUGH_TYPE = "strikethrough"
local CODE_SPAN_TYPE = "code_span"
local EMPHASIS_DELIM_TYPE = "emphasis_delimiter"
local CODE_SPAN_DELIM_TYPE = "code_span_delimiter"

local emphasis_queries = {
	[EMPHASIS_TYPE] = get_emphasis_query(EMPHASIS_TYPE),
	[STRONG_TYPE] = get_emphasis_query(STRONG_TYPE),
	[STRIKETHROUGH_TYPE] = get_emphasis_query(STRIKETHROUGH_TYPE),
	[CODE_SPAN_TYPE] = get_emphasis_query(CODE_SPAN_TYPE),
}

---@return table<string, { type: string, text: string }>
local function get_emphasis_by_key()
	local opts = config:get().inline_surround
	return {
		[opts.emphasis.key] = {
			type = EMPHASIS_TYPE,
			text = opts.emphasis.txt
		},
		[opts.strong.key] = {
			type = STRONG_TYPE,
			text = opts.strong.txt
		},
		[opts.strikethrough.key] = {
			type = STRIKETHROUGH_TYPE,
			text = opts.strikethrough.txt
		},
		[opts.code.key] = {
			type = CODE_SPAN_TYPE,
			text = opts.code.txt
		},
	}
end

---@param node TSNode
---@return boolean
local function is_inline(node)
	return node:type() == "inline"
end

---@param node TSNode
---@return boolean
local function is_emphasis_delim(node)
	local node_type = node:type()
	return node_type == EMPHASIS_DELIM_TYPE or node_type == CODE_SPAN_DELIM_TYPE
end

--- Gets start and end ranges of an emphasis node's emphasis group, where an emphasis group is a
--- nested group of one or more emphasis nodes.
---@param emphasis TSNode
---@return R4 start, R4 end group start and end ranges
---
--- The emphasis group for "***text***" consists of an emphasis node and a strong emphasis node.
--- The start and end ranges contain all '*' characters before and after "text", respectively.
local function get_emphasis_group_ranges(emphasis)
	local outer_node = emphasis
	local parent = outer_node:parent()
	while parent ~= nil do
		local delim_len = md_ts.child_count(parent, is_emphasis_delim) / 2
		if delim_len == 0 or not md_ts.spans_parent_range(outer_node, delim_len) then
			break
		end

		outer_node = parent
		parent = outer_node:parent()
	end

	local inner_node, inner_delim_len
	local child = emphasis
	---@cast child +?
	while child ~= nil and child ~= inner_node do
		local delim_len = md_ts.child_count(child, is_emphasis_delim) / 2
		if delim_len == 0 then
			break
		end

		inner_node = child
		inner_delim_len = delim_len

		local start_row, start_col, end_row, end_col = inner_node:range()
		-- the calling node is returned if a valid descendant can't be found
		child = inner_node:named_descendant_for_range(
			start_row, start_col + delim_len,
			end_row, end_col - delim_len
		)
	end

	if inner_node == nil then
		inner_node = emphasis
	end

	local outer_start_row, outer_start_col, outer_end_row, outer_end_col = outer_node:range()
	local inner_start_row, inner_start_col, inner_end_row, inner_end_col = inner_node:range()
	return { outer_start_row, outer_start_col, inner_start_row, inner_start_col + inner_delim_len },
		{ inner_end_row, inner_end_col - inner_delim_len, outer_end_row, outer_end_col }
end

--- Gets emphasis node adjusted for grammar rules the treesitter parser does not account for.
---@param emphasis TSNode
---@return TSNode
local function get_adjusted_emphasis_node(emphasis)
	-- parser treats double strikethrough as two nodes
	if emphasis:type() == STRIKETHROUGH_TYPE then
		local parent = emphasis:parent()
		if
			parent ~= nil
			and parent:type() == STRIKETHROUGH_TYPE
			and md_ts.spans_parent_range(emphasis)
		then
			return parent
		end
	end

	return emphasis
end

---@param emphasis TSNode
---@return integer
local function get_emphasis_delim_len(emphasis)
	if emphasis:type() == STRIKETHROUGH_TYPE then
		local start_row, start_col, end_row, end_col = emphasis:range()
		local child = emphasis:named_descendant_for_range(
			start_row, start_col + 1,
			end_row, end_col - 1
		)
		if
			child ~= nil
			and child ~= emphasis
			and child:type() == STRIKETHROUGH_TYPE
		then
			return 2
		end
	end

	return md_ts.child_count(emphasis, is_emphasis_delim) / 2
end

--- {toggle}{emphasis_key}: toggle emphasis over visual selection
---@param key? string
function M.toggle_emphasis_visual(key)
	M.toggle_emphasis(nil, key)
end

--- {toggle}{motion}{emphasis_key}: toggle emphasis over motion
---@param motion string|nil
---@param key? string
function M.toggle_emphasis(motion, key)
	if key == nil then
		local ok, char = util.try_get_char_input()
		if ok then
			M.toggle_emphasis(motion, char)
		end
		return
	end

	local emphasis_by_key = get_emphasis_by_key()
	local emphasis = emphasis_by_key[key]
	if emphasis == nil then
		return
	end

	local is_visual = motion == nil
	local is_visual_block = is_visual and vim.fn.visualmode() == "\22"

	local r
	if is_visual then
		r = util.get_visual_range()
	else
		r = util.get_motion_range(motion --[[@as string]])
	end

	local parser = ts.get_parser(0, "markdown")
	---@cast parser -?
	local t = parser:parse(r --[[@as Range4]])[1]
	local md_inline = parser:children().markdown_inline
	if md_inline == nil then
		return
	end
	local inline_trees = md_inline:parse()
	---@cast inline_trees -?
	local emphasis_query = emphasis_queries[emphasis.type]

	---@type TSNode[]
	local existing_emphasis = {}
	---@type R4[]
	local needs_emphasis = {}

	--- Adds to the `existing_emphasis` and `needs_emphasis` tables based on the specified
	--- `overlap` region.
	local function process_overlap(overlap, inline_tree)
		local found_existing = false
		local root, os, oe = inline_tree:root(), overlap[1], overlap[3] + 1
		for _, emphasis_node, _ in emphasis_query:iter_captures(root, 0, os, oe) do
			local emphasis_start_range, emphasis_end_range = get_emphasis_group_ranges(emphasis_node)
			-- adjust to match motion range directly within emphasis range
			emphasis_start_range[4] = emphasis_start_range[4] + 1
			emphasis_end_range[2] = emphasis_end_range[2] - 1
			if
				util.range_contains_position(emphasis_start_range, { overlap[1], overlap[2] })
				and util.range_contains_position(emphasis_end_range, { overlap[3], overlap[4] })
			then
				table.insert(existing_emphasis, get_adjusted_emphasis_node(emphasis_node))
				found_existing = true
				break
			end
		end

		if not found_existing then
			table.insert(needs_emphasis, overlap)
		end
	end

	local inline_count = 0
	if is_visual_block then
		local start_row, end_row = math.min(r[1], r[3]), math.max(r[1], r[3])
		local start_col, end_col = math.min(r[2], r[4]), math.max(r[2], r[4])
		for row = start_row, end_row, 1 do
			local eol_col = vim.fn.col({ row + 1, "$" }) - 1
			local row_start_col = math.min(start_col, eol_col)
			local row_end_col = math.min(end_col, eol_col)
			local inline_node = md_ts.find_node(is_inline, { pos = { row, math.max(row_end_col - 1, 0) } })
			if inline_node ~= nil and row_start_col ~= eol_col then
				inline_count = inline_count + 1

				local overlap = util.get_overlapping_range(
					{ row, row_start_col, row, row_end_col },
					---@diagnostic disable-next-line: missing-fields
					{ inline_node:range() }
				)
				local inline_t = md_ts.find_tree_in_node(inline_trees, inline_node)
				if inline_t == nil then
					local inline_txt = ts.get_node_text(inline_node, 0, nil)
					notify.error("Failed to find inline tree for node '%s'", inline_txt)
					return
				end
				process_overlap(overlap, inline_t)
			end
		end
	else
		for _, inline_node, _ in inline_query:iter_captures(t:root(), 0, r[1], r[3] + 1) do
			inline_count = inline_count + 1

			---@diagnostic disable-next-line: missing-fields
			local overlap = util.get_overlapping_range(r, { inline_node:range() })
			local inline_t = md_ts.find_tree_in_node(inline_trees, inline_node)
			if inline_t == nil then
				local inline_txt = ts.get_node_text(inline_node, 0, nil)
				notify.error("Failed to find inline tree for node '%s'", inline_txt)
				return
			end
			process_overlap(overlap, inline_t)
		end
	end

	if inline_count == #existing_emphasis then
		-- every inline range is already emphasized, so remove emphasis
		for i = #existing_emphasis, 1, -1 do
			local emphasis_node = existing_emphasis[i]
			local start_row, start_col, end_row, end_col = emphasis_node:range()
			local len = get_emphasis_delim_len(emphasis_node)
			util.delete_text(end_row, end_col - len, len)
			util.delete_text(start_row, start_col, len)
		end
	else
		-- add emphasis to non-emphasized inline ranges
		for i = #needs_emphasis, 1, -1 do
			local range = needs_emphasis[i]
			util.insert_text(range[3], range[4], emphasis.text)
			util.insert_text(range[1], range[2], emphasis.text)
		end
	end

	-- leave visual mode if successful
	if is_visual then
		local esc = api.nvim_replace_termcodes("<Esc>", true, false, true)
		api.nvim_feedkeys(esc, "n", false)
	end
end

--- {delete}{emphasis_key}: delete emphasis surrounding cursor
function M.delete_surrounding_emphasis()
	local ok, key = util.try_get_char_input()
	local emphasis_by_key = get_emphasis_by_key()
	if not ok or emphasis_by_key[key] == nil then
		return
	end

	local row, col = util.get_cursor()
	ts.get_parser(0, "markdown"):parse({ row, row + 1 })
	local emphasis = emphasis_by_key[key]
	local curr_node = ts.get_node({ pos = { row, col }, ignore_injections = false })
	while curr_node ~= nil and curr_node:type() ~= emphasis.type do
		curr_node = curr_node:parent()
	end

	if curr_node ~= nil then
		curr_node = get_adjusted_emphasis_node(curr_node)

		local start_row, start_col, end_row, end_col = curr_node:range()
		local len = get_emphasis_delim_len(curr_node)
		util.delete_text(end_row, end_col - len, len)
		util.delete_text(start_row, start_col, len)
	end
end

--- {change}{emphasis_key}{emphasis_key}: change emphasis surrounding cursor to another type
function M.change_surrounding_emphasis()
	local emphasis_by_key = get_emphasis_by_key()
	local from_ok, from_key = util.try_get_char_input()
	local to_ok, to_key = util.try_get_char_input()
	if
		not from_ok or not to_ok
		or emphasis_by_key[from_key] == nil
		or emphasis_by_key[to_key] == nil
	then
		return
	end

	local row, col = util.get_cursor()
	ts.get_parser(0, "markdown"):parse({ row, row + 1 })
	local from_emphasis = emphasis_by_key[from_key]
	local curr_node = ts.get_node({ pos = { row, col }, ignore_injections = false })
	while curr_node ~= nil and curr_node:type() ~= from_emphasis.type do
		curr_node = curr_node:parent()
	end

	if curr_node ~= nil then
		curr_node = get_adjusted_emphasis_node(curr_node)

		local start_row, start_col, end_row, end_col = curr_node:range()
		local len = get_emphasis_delim_len(curr_node)
		local to_emphasis = emphasis_by_key[to_key]
		util.replace_text(end_row, end_col - len, len, to_emphasis.text)
		util.replace_text(start_row, start_col, len, to_emphasis.text)
	end
end

return M
