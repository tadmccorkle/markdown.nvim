local api = vim.api
local ts = vim.treesitter

local md_ts = require("markdown.treesitter")

local M = {}

---@param node TSNode
---@return boolean
local function is_container(node)
	local type = node:type()
	return type == "list" or type == "block_quote"
end

---@param node TSNode
---@return boolean
local function is_section(node)
	return node:type() == "section"
		and md_ts.find_parent(node, is_container) == nil
end

---@param node TSNode
---@return boolean
local function is_section_heading(node)
	if is_section(node) then
		local child = node:named_child(0)
		local type = child ~= nil and child:type()
		return type == "atx_heading"
			or type == "setext_heading"
	end
	return false
end

---@param node TSNode
local function set_cursor(node)
	local row = node:start()
	api.nvim_win_set_cursor(0, { row + 1, 0 })
end

--- Sets the cursor to the current section's heading.
function M.curr_heading()
	ts.get_parser(0, "markdown"):parse()

	local curr = md_ts.find_node(is_section_heading)
	if curr ~= nil then
		set_cursor(curr)
	end
end

--- Sets the cursor to the parent section's heading of the current section.
function M.parent_heading()
	ts.get_parser(0, "markdown"):parse()

	local curr = md_ts.find_node(is_section)
	if curr == nil then
		return
	end

	local parent = md_ts.find_parent(curr, is_section_heading)
	if parent ~= nil then
		set_cursor(parent)
	end
end

--- Sets the cursor to the next heading.
function M.next_heading()
	ts.get_parser(0, "markdown"):parse()

	local curr = md_ts.find_node(is_section)
	if curr == nil then
		return
	end

	for child in curr:iter_children() do
		if is_section_heading(child) then
			set_cursor(child)
			return
		end
	end

	repeat
		local next = curr:next_named_sibling()
		if next ~= nil and is_section_heading(next) then
			local row = next:start()
			api.nvim_win_set_cursor(0, { row + 1, 0 })
			return
		end
		curr = md_ts.find_parent(curr, is_section_heading)
	until curr == nil
end

--- Sets the cursor to the previous heading.
function M.prev_heading()
	ts.get_parser(0, "markdown"):parse()

	local curr = md_ts.find_node(is_section)
	if curr == nil then
		return
	end

	local row = curr:start()
	if row == 0 then
		return
	end

	local prev = md_ts.find_node(is_section_heading, { pos = { row - 1, 0 } })
	if prev ~= nil then
		set_cursor(prev)
	end
end

return M
