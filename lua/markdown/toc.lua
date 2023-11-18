local api = vim.api
local ts = vim.treesitter

local Section = require("markdown.section")
local config = require("markdown.config")
local link = require("markdown.link")
local md_ts = require("markdown.treesitter")
local util = require("markdown.util")

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

---@enum omit_flag omit flag
local OMIT_FLAG = {
	none = 0,
	heading = 1,
	section = 2,
}

---@param html TSNode
---@return omit_flag
local function to_omit_flag(html, omit_section_flag, omit_heading_flag)
	local text = ts.get_node_text(html, 0, nil)
	if is_comment(text) then
		if text:match(omit_section_flag) ~= nil then
			return OMIT_FLAG.section
		elseif text:match(omit_heading_flag) ~= nil then
			return OMIT_FLAG.heading
		end
	end
	return OMIT_FLAG.none
end

---@param inline TSNode
---@return omit_flag
local function get_omit_flag(inline, omit_section_flag, omit_heading_flag)
	local inline_trees = ts.get_parser(0, "markdown"):children().markdown_inline:parse()
	local t = md_ts.find_tree_in_node(inline_trees, inline)
	if t ~= nil then
		for _, html_tag, _ in html_tag_query:iter_captures(t:root(), 0, 0, -1) do
			local flag = to_omit_flag(html_tag, omit_section_flag, omit_heading_flag)
			if flag ~= OMIT_FLAG.none then
				return flag
			end
		end
	end
	return OMIT_FLAG.none
end

---@return Section
local function get_document_sections()
	local t = ts.get_parser(0, "markdown"):parse()[1]

	local cfg = config:get()
	local omit_section_flag = cfg.toc.omit_section
	local omit_heading_flag = cfg.toc.omit_heading

	local omit_section_flags = {}
	local omit_heading_flags = {}
	for _, match, _ in html_block_query:iter_matches(t:root(), 0, 0, -1) do
		local html = match[1]
		local in_container = md_ts.find_parent(html, is_container)
		if not in_container then
			local omit_flag = to_omit_flag(html, omit_section_flag, omit_heading_flag)
			if omit_flag == OMIT_FLAG.section then
				omit_section_flags[html:end_()] = true
			elseif omit_flag == OMIT_FLAG.heading then
				omit_heading_flags[html:end_()] = true
			end
		end
	end

	local toc = Section:new()
	for _, match, _ in toc_heading_query:iter_matches(t:root(), 0, 0, -1) do
		local heading = match[5]
		local in_container = md_ts.find_parent(heading, is_container)
		if not in_container then
			local marker = match[1] or match[4]
			local content = match[2] or match[3]
			local level = tonumber(marker:type():match("(%d+)"))
			local name = ts.get_node_text(content, 0, nil)
			if level > toc.level then
				toc = toc:add_subsection(name, level --[[@as integer]])
			else
				toc = toc:get_parent(level):add_subsection(name, level --[[@as integer]])
			end

			local start = heading:start()
			if omit_section_flags[start] then
				toc.omit = true
			elseif omit_heading_flags[start] then
				toc.name = ""
			else
				local inner_omit_flag = get_omit_flag(content, omit_section_flag, omit_heading_flag)
				if inner_omit_flag == OMIT_FLAG.section then
					toc.omit = true
				elseif inner_omit_flag == OMIT_FLAG.heading then
					toc.name = ""
				end
			end
		end
	end

	return toc:get_root()
end

---@param toc Section
---@param tab string
---@param lines? string[]
---@param indent? integer
---@return string[]
local function build_toc_lines(toc, tab, lines, indent)
	lines = lines or {}
	indent = indent or 0

	for _, sub in pairs(toc.children) do
		if not sub.omit then
			local text, dest = link.get_heading_link(sub.name)
			if text ~= "" then
				local line = string.rep(tab, indent) .. "- [" .. text .. "](#" .. dest .. ")"
				table.insert(lines, line)
				build_toc_lines(sub, tab, lines, indent + 1)
			else
				build_toc_lines(sub, tab, lines, indent)
			end
		end
	end

	return lines
end

--- Inserts table of contents.
---@param opts table User command arguments table
---
---@see nvim_create_user_command
function M.insert_toc(opts)
	local toc = get_document_sections()
	local tab = util.get_tab_str()
	local lines = build_toc_lines(toc, tab)
	local start_row, end_row = util.get_user_command_range(opts)
	if start_row ~= end_row then
		end_row = end_row + 1
	end
	api.nvim_buf_set_lines(0, start_row, end_row, true, lines)
end

return M
