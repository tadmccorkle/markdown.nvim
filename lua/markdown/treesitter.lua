local ts = vim.treesitter

local M = {}

--- Finds the smallest node satisfying `predicate` based on the provided options.
---@param predicate fun(node: TSNode): boolean
---@param opts table? `vim.treesitter.get_node` opts
---@return TSNode|nil
---
---@see vim.treesitter.get_node
function M.find_node(predicate, opts)
	local node = ts.get_node(opts)
	while node ~= nil and not predicate(node) do
		node = node:parent()
	end
	return node
end

--- Finds parent of `node` satisfying `predicate`.
---@param node TSNode
---@param predicate fun(node: TSNode): boolean
function M.find_parent(node, predicate)
	local p = node:parent()
	while p ~= nil and not predicate(p) do
		p = p:parent()
	end
	return p
end

--- Gets the number of `node`'s children that satisfy `predicate`.
---@param node TSNode
---@param predicate fun(child: TSNode): boolean
---@return integer
function M.child_count(node, predicate)
	local count = 0
	for child in node:iter_children() do
		if predicate(child) then
			count = count + 1
		end
	end
	return count
end

--- Determines if `node` has the same type as its immediate parent.
---@param node TSNode
---@return boolean
function M.has_parent_type(node)
	local parent = node:parent()
	return parent and node:type() == parent:type()
end

--- Determines if `node` spans the inner range of its immediate parent.
---@param node TSNode
---@param inner_col_offset? integer `1` if not provided
---@return boolean
---
--- The inner column offset is used to narrow the subrange of the parent checked. For example, if
--- the node's range is `{ 0, 2, 1, 8 }` and its parent range is `{ 0, 0, 1, 10 }`, this will return
--- true given an offset of `2`.
function M.spans_parent_range(node, inner_col_offset)
	local parent = node:parent()
	if parent == nil then
		return false
	end

	local range = { node:range() }
	local parent_range = { parent:range() }

	inner_col_offset = inner_col_offset or 1
	return range[1] == parent_range[1] and range[3] == parent_range[3]
		and range[2] == parent_range[2] + inner_col_offset
		and range[4] == parent_range[4] - inner_col_offset
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

---@param text string
---@param node_type string
---@param root TSNode
---@return string
local function remove_nodes(text, node_type, root)
	for i = root:named_child_count() - 1, 0, -1 do
		local child = root:named_child(i)
		if child:type() == node_type then
			local _, s, _, e = child:range()
			text = string.sub(text, 1, s) .. string.sub(text, e + 1)
		else
			text = remove_nodes(text, node_type, child)
		end
	end
	return text
end

--- Returns the provided text with the specified nodes removed.
---@param text string Text to parse
---@param lang string Language of text
---@param node_type string Type of nodes to remove
---@return string
function M.remove_nodes(text, lang, node_type)
	local t = ts.get_string_parser(text, lang):parse()[1]:root()
	return remove_nodes(text, node_type, t)
end

return M
