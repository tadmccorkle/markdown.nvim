local api = vim.api
local ts = vim.treesitter

local Section = MDR("markdown.section")
local md_ts = MDR("markdown.treesitter")
local util = MDR("markdown.util")

local M = {}

local toc_heading_query = ts.query.parse("markdown", [[
	(atx_heading
		(_) @atx_marker
		heading_content: (inline) @atx_content) @atx_heading
	(setext_heading
		heading_content: (_ (inline) @setext_content)
		(_) @setext_underline) @setext_heading
	(html_block) @html
]])
local TOC_ATX_IDS = { MARKER = 1, CONTENT = 2, HEADING = 3 }
local TOC_SET_IDS = { MARKER = 5, CONTENT = 4, HEADING = 6 }
local TOC_HTML_ID = 7

local html_tag_query = ts.query.parse("markdown_inline", "(html_tag) @html")

---@param html TSNode|string
---@return boolean
local function is_comment(html)
	local text
	if type(html) == "string" then
		text = html
	else
		text = ts.get_node_text(html, 0, nil)
	end
	return #text > 3 and text:sub(1, 4) == "<!--" and text:sub(-3, -1) == "-->"
end

---@param html TSNode
---@return boolean
local function is_omit_flag(html)
	local text = ts.get_node_text(html, 0, nil)
	return (is_comment(text) and text:match("omit in toc") ~= nil)
end

---@param inline TSNode
---@return boolean
local function has_omit_flag(inline)
	local inline_trees = ts.get_parser(0, "markdown"):children().markdown_inline:parse()
	local t = md_ts.find_tree_in_node(inline_trees, inline)
	if t ~= nil then
		for _, match, _ in html_tag_query:iter_matches(t:root(), 0, 0, -1) do
			if is_omit_flag(match[1]) then
				return true
			end
		end
	end
	return false
end

---@return Section
local function get_document_sections()
	local t = ts.get_parser(0, "markdown"):parse()[1]

	local toc = Section:new()
	local last_omit_flag_end_row
	for _, match, _ in toc_heading_query:iter_matches(t:root(), 0, 0, -1) do
		local _, n = next(match)
		if not md_ts.is_contained_by_any_of(n, { "list", "block_quote" }) then
			local html = match[TOC_HTML_ID]
			if html ~= nil then
				if is_omit_flag(html) then
					last_omit_flag_end_row, _, _ = html:end_()
				end
			else
				local heading_ids
				if match[TOC_ATX_IDS.HEADING] ~= nil then
					heading_ids = TOC_ATX_IDS
				else
					heading_ids = TOC_SET_IDS
				end

				local heading_start_row, _, _ = match[heading_ids.HEADING]:start()
				if last_omit_flag_end_row ~= heading_start_row and not has_omit_flag(match[heading_ids.CONTENT]) then
					local level = tonumber(match[heading_ids.MARKER]:type():match("(%d+)"))
					local name = util.sanitize(ts.get_node_text(match[heading_ids.CONTENT], 0, nil))
					if level > toc.level then
						toc = toc:add_subsection(name, level)
					else
						toc = toc:get_parent(level):add_subsection(name, level)
					end
				end
			end
		end
	end

	return toc:get_root()
end

---@param toc Section
---@param lines? string[]
---@param indent? integer
---@return string[]
local function build_toc_lines(toc, lines, indent)
	lines = lines or {}
	indent = indent or 0
	for _, sub in pairs(toc.children) do
		local line = (string.rep("  ", indent) .. "- [" .. sub.name .. "](#" .. util.slugify(sub.name) .. ")")
		table.insert(lines, line)
		build_toc_lines(sub, lines, indent + 1)
	end
	return lines
end

--- Inserts table of contents at the cursor in the current buffer.
function M.insert_toc()
	local toc = get_document_sections()
	local lines = build_toc_lines(toc)
	local row = api.nvim_win_get_cursor(0)[1] - 1 -- 1-based row, 0-based col
	api.nvim_buf_set_lines(0, row, row, true, lines)
end

return M
