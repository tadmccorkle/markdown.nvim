local ts = vim.treesitter

local md_ts = require("markdown.treesitter")
local util = require("markdown.util")

local M = {}

local query = ts.query.parse(
	"markdown",
	[[
	[
		(atx_heading
			(_) @atx_marker
			heading_content: (inline) @atx_content)
		(setext_heading
			heading_content: (_ (inline) @setext_content)
			(_) @setext_underline)
	] @heading
]]
)

---@param node TSNode
---@return boolean
local function is_container(node)
	local type = node:type()
	return type == "list" or type == "block_quote"
end

--- Gets sanitized heading text and its base slug (without document deduplication).
---@param text string
---@return string text, string destination
function M.get_link(text)
	local content = util.sanitize(text)
	local dest = md_ts.remove_nodes(content, "markdown_inline", "emphasis_delimiter")
	return content, util.slugify(dest)
end

---@class MarkdownHeading
---@field node TSNode
---@field content TSNode
---@field name string
---@field text string
---@field destination string
---@field level integer
---@field line integer

--- Assign destinations before any TOC filtering, using all non-container headings.
---@param root TSNode
---@return MarkdownHeading[]
function M.get_document_headings(root)
	local headings = {}
	local used = {}
	for _, match, _ in query:iter_matches(root, 0, 0, -1, { all = true }) do
		local node = md_ts.single_node_from_match(match, 5)
		if not md_ts.find_parent(node, is_container) then
			local marker = md_ts.single_node_from_match(match, 1)
				or md_ts.single_node_from_match(match, 4)
			local content = md_ts.single_node_from_match(match, 2)
				or md_ts.single_node_from_match(match, 3)
			local name = ts.get_node_text(content, 0, nil)
			local text, base = M.get_link(name)
			local dest = base
			local suffix = used[base] or 0
			while used[dest] ~= nil do
				suffix = suffix + 1
				dest = base .. "-" .. suffix
			end
			used[base] = suffix
			used[dest] = 0
			table.insert(headings, {
				node = node,
				content = content,
				name = name,
				text = text,
				destination = dest,
				level = tonumber(marker:type():match("(%d+)")),
				line = node:start() + 1,
			})
		end
	end
	return headings
end

return M
