local api = vim.api
local ts = vim.treesitter

local Section = require("markdown.section")
local config = require("markdown.config")
local link = require("markdown.link")
local list = require("markdown.list")
local md_ts = require("markdown.treesitter")

local M = {}

local toc_heading_query = ts.query.parse("markdown", [[
	[
		(atx_heading
			(_) @atx_marker
			heading_content: (inline) @atx_content)
		(setext_heading
			heading_content: (_ (inline) @setext_content)
			(_) @setext_underline)
	] @heading
]])

local html_block_query = ts.query.parse("markdown", "(html_block) @html")
local html_tag_query = ts.query.parse("markdown_inline", "(html_tag) @html")

---@param node TSNode
---@return boolean
local function is_container(node)
	local type = node:type()
	return type == "list" or type == "block_quote"
end

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
---@return omit_level
local function to_omit_flag(html, omit_section_flag, omit_heading_flag)
	local text = ts.get_node_text(html, 0, nil)
	if is_comment(text) then
		if text:match(omit_section_flag) ~= nil then
			return Section.OMIT_LEVEL.section
		elseif text:match(omit_heading_flag) ~= nil then
			return Section.OMIT_LEVEL.heading
		end
	end
	return Section.OMIT_LEVEL.none
end

---@param inline TSNode
---@return omit_level
local function get_omit_flag(inline, omit_section_flag, omit_heading_flag)
	local parser = ts.get_parser(0, "markdown")
	---@cast parser -?

	parser:parse({ inline:start(), inline:end_() + 1 })

	local inline_trees = parser:children().markdown_inline:parse()
	---@cast inline_trees -?

	local t = md_ts.find_tree_in_node(inline_trees, inline)
	if t ~= nil then
		for _, html_tag, _ in html_tag_query:iter_captures(t:root(), 0, 0, -1) do
			local flag = to_omit_flag(html_tag, omit_section_flag, omit_heading_flag)
			if flag ~= Section.OMIT_LEVEL.none then
				return flag
			end
		end
	end
	return Section.OMIT_LEVEL.none
end

---@return Section
local function get_document_sections()
	local t = ts.get_parser(0, "markdown"):parse()[1]

	local cfg = config:get()
	local omit_section_flag = cfg.toc.omit_section
	local omit_heading_flag = cfg.toc.omit_heading

	local omit_section_flags = {}
	local omit_heading_flags = {}
	for _, match, _ in html_block_query:iter_matches(t:root(), 0, 0, -1, { all = true }) do
		local html = md_ts.single_node_from_match(match, 1)
		local in_container = md_ts.find_parent(html, is_container)
		if not in_container then
			local omit_flag = to_omit_flag(html, omit_section_flag, omit_heading_flag)
			if omit_flag == Section.OMIT_LEVEL.section then
				omit_section_flags[html:end_()] = true
			elseif omit_flag == Section.OMIT_LEVEL.heading then
				omit_heading_flags[html:end_()] = true
			end
		end
	end

	local toc = Section:new()
	for _, match, _ in toc_heading_query:iter_matches(t:root(), 0, 0, -1, { all = true }) do
		local heading = md_ts.single_node_from_match(match, 5)
		local in_container = md_ts.find_parent(heading, is_container)
		if not in_container then
			local marker = md_ts.single_node_from_match(match, 1)
				or md_ts.single_node_from_match(match, 4)
			local content = md_ts.single_node_from_match(match, 2)
				or md_ts.single_node_from_match(match, 3)
			local name = ts.get_node_text(content, 0, nil)
			local level = tonumber(marker:type():match("(%d+)")) --[[@as integer]]
			local line = heading:start() + 1

			if level > toc.level then
				toc = toc:add_subsection(name, level, line)
			else
				toc = toc:get_parent(level):add_subsection(name, level, line)
			end

			local start = heading:start()
			if omit_section_flags[start] then
				toc.omit = Section.OMIT_LEVEL.section
			elseif omit_heading_flags[start] then
				toc.omit = Section.OMIT_LEVEL.heading
			else
				local inner_omit_flag = get_omit_flag(content, omit_section_flag, omit_heading_flag)
				if inner_omit_flag == Section.OMIT_LEVEL.section then
					toc.omit = Section.OMIT_LEVEL.section
				elseif inner_omit_flag == Section.OMIT_LEVEL.heading then
					toc.omit = Section.OMIT_LEVEL.heading
				end
			end
		end
	end

	return toc:get_root()
end

---@param toc Section
---@param markers string[]
---@param max_level integer
---@param lines? string[]
---@param depth? integer
---@param indent? string
---@return string[]
local function build_toc_lines(toc, markers, max_level, lines, depth, indent)
	lines = lines or {}
	depth = depth or 0
	indent = indent or ""

	local marker = markers[(depth % #markers) + 1]
	local sub_indent = indent .. string.rep(" ", #marker + 1)

	for _, sub in pairs(toc.children) do
		local omit_section = sub.omit == Section.OMIT_LEVEL.section or sub.level > max_level
		if not omit_section then
			local text, dest = link.get_heading_link(sub.name)
			local omit_heading = sub.omit == Section.OMIT_LEVEL.heading or text == ""
			if not omit_heading then
				local line = indent .. marker .. " [" .. text .. "](#" .. dest .. ")"
				table.insert(lines, line)
				build_toc_lines(sub, markers, max_level, lines, depth + 1, sub_indent)
			else
				build_toc_lines(sub, markers, max_level, lines, depth, indent)
			end
		end
	end

	return lines
end

---@class InsertOpts
---@field markers string[] List markers
---@field start_row integer Zero-based start row
---@field end_row? integer Zero-based end row
---@field max_level? integer Max heading level to include (default: '6')

--- Inserts table of contents.
---@param opts InsertOpts
---
--- If an `end_row` is not specified, table of contents is inserted at the start row. If an
--- `end_row` is specified, table of contents replaces the range [`start_row`-`end_row`].
function M.insert_toc(opts)
	local toc = get_document_sections()

	local markers = {}
	for i, m in ipairs(opts.markers) do
		if m == "." or m == ")" then
			markers[i] = "1" .. m
		else
			markers[i] = m
		end
	end
	local max_level = opts.max_level or 6
	local lines = build_toc_lines(toc, markers, max_level)

	local end_row
	if opts.end_row ~= nil then
		end_row = opts.end_row + 1
	else
		end_row = opts.start_row
	end

	api.nvim_buf_set_lines(0, opts.start_row, end_row, true, lines)
	list.reset_list_numbering(opts.start_row, opts.start_row + #lines - 1)
end

---@param toc Section
---@param opts { bufnr: integer, max_level: integer, omit_flagged: boolean, indent_subsections: boolean }
---@param loclist? table[]
---@param indent? string
local function build_toc_loclist(toc, opts, loclist, indent)
	loclist = loclist or {}
	indent = indent or ""

	local sub_indent
	if opts.indent_subsections then
		sub_indent = indent .. "  "
	else
		sub_indent = indent
	end

	for _, sub in pairs(toc.children) do
		local omit_section = opts.omit_flagged and sub.omit == Section.OMIT_LEVEL.section
		if not omit_section and sub.level <= opts.max_level then
			local text = link.get_heading_link(sub.name)
			local omit_heading = opts.omit_flagged and sub.omit == Section.OMIT_LEVEL.heading
			if not omit_heading and text ~= "" then
				table.insert(loclist, {
					bufnr = opts.bufnr,
					lnum = sub.line,
					text = indent .. text
				})
				build_toc_loclist(sub, opts, loclist, sub_indent)
			else
				build_toc_loclist(sub, opts, loclist, indent)
			end
		end
	end

	return loclist
end

---@class LoclistOpts
---@field max_level? integer Max heading level to include (default: '6')
---@field omit_flagged? boolean Whether to omit flagged sections and headings (default: 'false')
---@field indent_subsections? boolean Whether to indent subsection headings (default: 'false')

--- Sets the current window's location list to the table of contents.
---@param opts? LoclistOpts
---
--- This function only sets the location list. It must subsequently be searched or opened directly
--- (e.g., `:lopen`). The location list set by this function has a quickfix context property
--- `{ markdown_nvim_toc = true }`.
function M.set_loclist_toc(opts)
	opts = opts or {}

	local toc = get_document_sections()
	local bufnr = api.nvim_win_get_buf(0)
	local loclist = build_toc_loclist(toc, {
		bufnr = bufnr,
		max_level = opts.max_level or 6,
		omit_flagged = opts.omit_flagged or false,
		indent_subsections = opts.indent_subsections or false,
	})

	vim.fn.setloclist(0, {}, "r", {
		title = "Table of Contents",
		items = loclist,
		context = { markdown_nvim_toc = true },
	})
end

return M
