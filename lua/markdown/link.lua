local api = vim.api
local ts = vim.treesitter

local config = require("markdown.config")
local md_ts = require("markdown.treesitter")
local notify = require("markdown.notify")
local util = require("markdown.util")

local M = {}

local is_registered = false

local heading_query = ts.query.parse("markdown", [[
	[
		(atx_heading
			_ heading_content: (inline) @atx_content)
		(setext_heading
			heading_content: (_ (inline) @setext_content) _)
	] @heading
]])

---@param text string
---@return boolean
function M.is_url(text)
	local s, e = string.find(text, "https?://" .. "%w" .. "[%w@:%%._+~#=/%-?&]*")
	if s == nil or e == nil then
		s, e = string.find(text, "www%." .. "%w" .. "[%w@:%%._+~#=/%-?&]*")
		if s == nil or e == nil then
			return false
		end
	end
	return (e + 1) - s == #text
end

---@param node TSNode
---@return boolean
local function is_container(node)
	local type = node:type()
	return type == "list" or type == "block_quote"
end

---@param node TSNode
---@return boolean
local function is_inline(node)
	return node:type() == "inline"
end

---@param node TSNode
---@return boolean
local function is_link(node)
	return node:type() == "inline_link"
end

---@param node TSNode
---@return boolean
local function is_link_dest(node)
	return node:type() == "link_destination"
end

---@see vim.paste
local function paste_handler(overridden)
	return function(lines, phase)
		local mode = api.nvim_get_mode().mode
		local is_visual = mode == "v" or mode == "V"
		local is_md = vim.b.markdown_nvim_attached == 1
		if not (is_visual and is_md and #lines == 1) then
			overridden(lines, phase)
			return
		end

		local url = lines[1]
		if not M.is_url(url) then
			overridden(lines, phase)
			return
		end

		local esc = api.nvim_replace_termcodes("<Esc>", true, false, true)
		api.nvim_feedkeys(esc .. "gv", "x", false)

		local r = util.get_visual_range()
		ts.get_parser(0, "markdown"):parse()

		local inline = md_ts.find_node(is_inline, { pos = { r[1], r[2] } })
		if inline ~= nil and ts.node_contains(inline, r) then
			lines = api.nvim_buf_get_text(0, r[1], r[2], r[3], r[4], {})
			lines[1] = "[" .. lines[1]
			lines[#lines] = lines[#lines] .. "](" .. url .. ")"
		end

		overridden(lines, phase)
	end
end

--- Registers a paste handler to convert URLs into markdown links.
---
--- URLs are only converted to markdown links when:
--- * Pasting over visual selection (not a block selection)
--- * Visual selection is contained by one inline block (i.e., conversion will
---   not happen if visual selection includes blank lines, list markers, etc.)
---
---@see vim.paste
function M.register_paste_handler()
	if not is_registered then
		is_registered = true
		vim.paste = paste_handler(vim.paste)
	end
end

--- Adds link over visual selection.
function M.add_visual()
	M.add(nil)
end

--- Adds link over motion.
---@param motion string|nil
function M.add(motion)
	local is_visual = motion == nil

	local is_visual_block = is_visual and vim.fn.visualmode() == "\22"
	if is_visual_block then
		return
	end

	local r
	if is_visual then
		r = util.get_visual_range()
	else
		r = util.get_motion_range(motion --[[@as string]])
	end

	ts.get_parser(0, "markdown"):parse()
	local inline = md_ts.find_node(is_inline, { pos = { r[1], r[2] } })
	if inline == nil or not ts.node_contains(inline, r) then
		return
	end

	local ok, input = util.try_get_input("Link destination: ")
	if not ok then
		return
	end

	util.insert_text(r[3], r[4], "](" .. input .. ")")
	util.insert_text(r[1], r[2], "[")

	-- leave visual mode if successful
	if is_visual then
		local esc = api.nvim_replace_termcodes("<Esc>", true, false, true)
		api.nvim_feedkeys(esc, "n", false)
	end
end

---@param dest string
---@param root TSNode
local function follow_heading_link(dest, root)
	for _, match, _ in heading_query:iter_matches(root, 0, 0, -1) do
		local _, content = next(match)
		local _, heading = next(match)
		local in_container = md_ts.find_parent(heading, is_container)
		if not in_container then
			local text = ts.get_node_text(content, 0, nil)
			text = util.sanitize(text)
			text = md_ts.remove_nodes(text, "markdown_inline", "emphasis_delimiter")
			text = util.slugify(text)
			if text == dest then
				local row, _, _ = heading:start()
				api.nvim_win_set_cursor(0, { row + 1, 0 })
				return
			end
		end
	end
	notify.info("heading not found")
end

---@param url string
local function open_url(url)
	local sys = vim.loop.os_uname().sysname
	if sys == "Windows_NT" then
		vim.fn.system({ "explorer.exe", url })
	elseif sys == "Linux" then
		vim.fn.system("xdg-open", url)
	elseif sys == "Darwin" then
		vim.fn.system("open", url)
	else
		notify.error("OS '%s' URL navigation is not supported.", sys)
	end
end

---@param path string
local function open_path(path)
	if vim.startswith(path, ".") then
		path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)) .. string.sub(path, 2)
	elseif vim.startswith(path, "/") then
		path = vim.fn.getcwd() .. path
	end

	local normalized = vim.fs.normalize(path)
	if vim.fn.filereadable(normalized) ~= 0 or vim.fn.isdirectory(normalized) ~= 0 then
		vim.cmd.edit(path)
	else
		notify.info("path not found")
	end
end

--- Follows or opens the destination of the link under the cursor.
function M.follow()
	local cursor = api.nvim_win_get_cursor(0) -- 1-based row, 0-based col
	cursor[1] = cursor[1] - 1

	local t = ts.get_parser(0, "markdown"):parse()[1]
	local link = md_ts.find_node(is_link, { ignore_injections = false })
	if link == nil then
		return
	end

	local dest_node = md_ts.find_child(link, is_link_dest)
	local dest = ts.get_node_text(dest_node, 0, nil)

	local function follow_link()
		if vim.startswith(dest, "#") then
			dest = string.sub(dest, 2)
			follow_heading_link(dest, t:root())
		elseif M.is_url(dest) then
			open_url(dest)
		else
			open_path(dest)
		end
	end

	local override = config:get().hooks.follow_link
	if override ~= nil then
		override(dest, follow_link)
	else
		follow_link()
	end
end

return M
