local api = vim.api
local ts = vim.treesitter

local M = {}

---@class Position
---@field [1] integer row zero-based
---@field [2] integer col zero-based

--- Finds the `tree`'s innermost match for `query` at the `pos`, if one exists.
---@param tree TSTree Treesitter tree
---@param query Query Treesitter query
---@param pos Position Zero-based row/col position
---@return table<integer, TSNode>|nil
function M.find_innermost_match_containing(tree, query, pos)
	local match
	local min_range = api.nvim_buf_line_count(0)
	for _, m, _ in query:iter_matches(tree:root(), 0, pos[1], pos[1] + 1) do
		for _, node in pairs(m) do
			local node_start_row, _, node_end_row, _ = node:range()
			local node_range = node_end_row - node_start_row
			if ts.node_contains(node, { pos[1], pos[2], pos[1], pos[2] }) and node_range < min_range then
				match = m
				min_range = node_range
			end
		end
	end
	return match
end

--- Finds a tree from `trees` contained within the `node`.
---@param trees TSTree[]
---@param node TSNode
---@return TSTree|nil
function M.find_tree_in_node(trees, node)
	for _, t in pairs(trees) do
		if ts.node_contains(node, { t:root():range() }) then
			return t
		end
	end
end

--- Determines if the `node` has an ancestor of one of the provided `types`.
---@param node TSNode
---@param types string[]
---@return boolean
function M.is_contained_by_any_of(node, types)
	local p = node:parent()
	while p ~= nil do
		for _, type in pairs(types) do
			if p:type() == type then
				return true
			end
		end
		p = p:parent()
	end
	return false
end

--- Gets the smallest node of the given type based on the provided options.
---@param type string Type of node to get
---@param opts table|nil `vim.treesitter.get_node` opts
---@return TSNode|nil
---
---@see vim.treesitter.get_node
function M.get_node_of_type(type, opts)
	local node = ts.get_node(opts)
	while node ~= nil and node:type() ~= type do
		node = node:parent()
	end
	return node
end

return M
