local api = vim.api
local ts = vim.treesitter

local config = require("markdown.config")
local md_ts = require("markdown.treesitter")
local heading = require("markdown.heading")
local notify = require("markdown.notify")
local util = require("markdown.util")

local M = {}

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
		---@diagnostic disable-next-line: undefined-field
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

local is_registered = false

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

	util.insert_text(r[3], r[4], "]()")
	util.insert_text(r[1], r[2], "[")

	-- leave visual mode if successful
	if is_visual then
		local esc = api.nvim_replace_termcodes("<Esc>", true, false, true)
		api.nvim_feedkeys(esc, "n", false)
	end

	-- enter insert mode to type destination
	local col = r[4] + 2
	if r[1] == r[3] then
		col = col + 1
	end
	api.nvim_win_set_cursor(0, { r[3] + 1, col })
	vim.cmd("startinsert")
end

--- Gets the sanitized text and slugified destination of a heading link.
---@deprecated Use require("markdown.heading").get_link instead.
---@param text string Heading text
---@return string text, string destination
function M.get_heading_link(text)
	return heading.get_link(text)
end

---@param dest string
---@param root TSNode
---@param silent? boolean
---@return boolean found
local function follow_heading_link(dest, root, silent)
	dest = string.sub(dest, 2)

	for _, h in ipairs(heading.get_document_headings(root)) do
		if h.destination == dest then
			vim.cmd.normal({ "m'", bang = true })
			api.nvim_win_set_cursor(0, { h.line, 0 })
			return true
		end
	end

	if not silent then
		notify.info("heading not found")
	end

	return false
end

---@param dest string
---@return string? error
local function open(dest)
	local ok, cmd, err = pcall(vim.ui.open, dest)
	if not ok then
		return tostring(cmd)
	end

	local rv = cmd and cmd:wait(1000) or nil
	if cmd and rv and rv.code ~= 0 then
		err = ("command %s (%d): %s"):format(
			(rv.code == 124 and "timeout" or "failed"),
			rv.code,
			vim.inspect(cmd.cmd)
		)
	end
	return err
end

---@param url string
local function open_url(url)
	if not url:match("^%a+://") then
		url = "https://" .. url
	end

	local err = open(url)
	if err ~= nil then
		notify.error("URL navigation failed. " .. err)
	end
end

---@param path string
---@param opts FollowOpts
local function open_path(path, opts)
	if vim.startswith(path, "/") then
		path = vim.fn.getcwd() .. path
	elseif vim.startswith(path, "./") or vim.startswith(path, ".\\") then
		path = vim.fs.dirname(vim.api.nvim_buf_get_name(0)) .. string.sub(path, 2)
	elseif vim.startswith(path, "../") or vim.startswith(path, "..\\") then
		path = vim.fs.dirname(vim.fs.dirname(vim.api.nvim_buf_get_name(0))) .. string.sub(path, 3)
	end

	local normalized = vim.fs.normalize(path)
	local is_file = vim.fn.filereadable(normalized) ~= 0
	local is_dir = vim.fn.isdirectory(normalized) ~= 0
	local inner_dest, line

	-- An existing literal path (including a directory) takes precedence over fragments.
	if not is_file and not is_dir then
		local base, fragment = path:match("^(.*)#([^#/]+)$")
		if fragment ~= nil then
			local number = fragment:match("^L([0-9]+)$")
				or fragment:match("^L([0-9]+)%-L[0-9]+$")
				or fragment:match("^L([0-9]+)%-[0-9]+$")
			line = number and tonumber(number) or nil
			if line ~= nil or base:sub(-3) == ".md" then
				inner_dest = "#" .. fragment
				path = base
				normalized = vim.fs.normalize(path)
				is_file = vim.fn.filereadable(normalized) ~= 0
			end
		end
	end

	if is_file or is_dir then
		local is_md = string.sub(path, -3) == ".md"
		if opts.use_default_app and not is_md and not is_dir then
			local err = open(normalized)
			if err ~= nil then
				notify.error("Open in default app failed. " .. err)
			end
		else
			vim.cmd.edit(vim.fn.fnameescape(path))

			if inner_dest ~= nil then
				local found = false

				if is_md then
					local ok, p = pcall(ts.get_parser, 0, "markdown")
					if ok and p ~= nil then
						local parsed, trees = pcall(p.parse, p)
						if parsed and trees and trees[1] then
							found = follow_heading_link(inner_dest, trees[1]:root(), line ~= nil)
						end
					end
				end

				if not found and line ~= nil then
					line = math.max(1, math.min(line, api.nvim_buf_line_count(0)))
					api.nvim_win_set_cursor(0, { line, 0 })
				end
			end
		end
	else
		notify.info("path not found")
	end
end

---@class FollowOpts
---@field use_default_app? boolean Open non-markdown path with default application (default: 'false')

--- Follows or opens the destination of the link under the cursor.
---@param opts FollowOpts?
function M.follow(opts)
	opts = opts or {}

	local row, col = util.get_cursor()
	local t = ts.get_parser(0, "markdown"):parse({ row, row + 1 })[1]
	local link = md_ts.find_node(is_link, { pos = { row, col }, ignore_injections = false })
	if link == nil then
		return
	end

	local dest_node = md_ts.find_child(link, is_link_dest)
	if dest_node == nil then
		return
	end
	local dest = ts.get_node_text(dest_node, 0, nil)

	local function follow_link()
		if vim.startswith(dest, "#") then
			follow_heading_link(dest, t:root())
		elseif M.is_url(dest) then
			open_url(dest)
		else
			open_path(dest, opts)
		end
	end

	local override = config:get().hooks.follow_link
	if override ~= nil then
		local o_opts = vim.tbl_extend("error", opts, { dest = dest })
		override(o_opts, follow_link)
	else
		follow_link()
	end
end

return M
