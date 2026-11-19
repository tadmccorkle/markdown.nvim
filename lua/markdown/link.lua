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

---@param text string
---@return boolean
function M.is_uri(text)
	local is_drive = text:match("^[A-Za-z]:[/\\]") ~= nil
		or (vim.fn.has("win32") == 1 and text:match("^[A-Za-z]:") ~= nil)
	return not is_drive and text:match("^[A-Za-z][A-Za-z0-9+.-]*:") ~= nil
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
		if url:find("%s") or not (M.is_uri(url) or M.is_url(url)) then
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

--- Registers a paste handler to convert URIs and www. URLs into markdown links.
---
--- Destinations are only converted to markdown links when:
--- * Pasted text is a single line without whitespace
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
	local err = open(url)
	if err ~= nil then
		notify.error("URL navigation failed. " .. err)
	end
end

---@param line_num string
---@return integer
local function parse_line(line_num)
	return math.min(tonumber(line_num) or 0, 2147483647)
end

local markdown_extensions = {
	md = true,
	markdown = true,
	mdown = true,
	mkd = true,
	mkdn = true,
	mdwn = true,
}

---@param path string
---@return boolean
local function is_markdown_path(path)
	local filetype = vim.filetype.match({ filename = path })
	if filetype ~= nil then
		return filetype == "markdown"
	end

	-- Filename detection is case-sensitive; accept standard Markdown suffixes
	-- in any case, but do not override an explicit non-Markdown filetype.
	local extension = path:match("%.([^./\\]+)$")
	return extension ~= nil and markdown_extensions[extension:lower()] == true
end

---@param path string
local function resolve_path(path)
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
	local inner_dest, line_range

	-- An existing literal path (including a directory) takes precedence over fragments.
	if not is_file and not is_dir then
		local base, fragment = path:match("^(.*)#([^#/]+)$")
		if fragment ~= nil then
			local first, last = fragment:match("^L([0-9]+)%-L?([0-9]+)$")
			first = first or fragment:match("^L([0-9]+)$")
			if first ~= nil then
				line_range = {
					start_line = parse_line(first),
					end_line = parse_line(last or first),
				}
			end
			if line_range ~= nil or is_markdown_path(base) then
				inner_dest = "#" .. fragment
				path = base
				normalized = vim.fs.normalize(path)
				is_file = vim.fn.filereadable(normalized) ~= 0
			end
		end
	end

	-- Normalize does not make bare relative paths absolute. Capture cwd now so
	-- the hook and fallback agree even if the hook changes it.
	normalized = vim.fs.normalize(vim.fn.fnamemodify(normalized, ":p"))
	local stat, _, code = vim.uv.fs_stat(normalized)
	local path_type = "unknown"
	if stat ~= nil then
		path_type = stat.type == "file" and "file"
			or (stat.type == "directory" and "directory" or "other")
	elseif code == "ENOENT" or code == "ENOTDIR" then
		path_type = "missing"
	end

	return {
		path = normalized,
		fragment = inner_dest,
		line_range = line_range,
		path_type = path_type,
		is_markdown = is_markdown_path(normalized),
		-- Preserve the default follower's readability and directory policy.
		is_file = is_file,
		is_dir = is_dir,
	}
end

---@param target table
---@param opts markdown.link.FollowOpts
local function open_path(target, opts)
	if not (target.is_file or target.is_dir) then
		notify.info("path not found")
		return
	end

	local path = target.path
	local inner_dest = target.fragment
	local line = target.line_range and target.line_range.start_line

	if opts.use_default_app and not (target.is_markdown or target.is_dir) then
		local err = open(path)
		if err ~= nil then
			notify.error("Open in default app failed. " .. err)
		end
	else
		vim.cmd.edit(vim.fn.fnameescape(path))

		if inner_dest ~= nil then
			local found = false

			if target.is_markdown then
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
end

---@class markdown.link.FollowOpts
---@field use_default_app? boolean Open non-markdown path with default application (default: 'false')

--- Follows or opens the destination of the link under the cursor.
---@param opts markdown.link.FollowOpts?
function M.follow(opts)
	local ok, link, dest, t = pcall(function()
		local row, col = util.get_cursor()
		local tree = ts.get_parser(0, "markdown"):parse({ row, row + 1 })[1]
		if tree == nil then
			return
		end

		local node = md_ts.find_node(is_link, { pos = { row, col }, ignore_injections = false })
		if node == nil then
			return
		end

		local dest_node = md_ts.find_child(node, is_link_dest)
		return node, dest_node and ts.get_node_text(dest_node, 0, nil), tree
	end)

	if not ok or link == nil or t == nil then
		require("markdown.link_mapping").fallback()
		return
	end

	if dest == nil or dest == "" then
		return
	end

	local kind, target, external_dest
	if vim.startswith(dest, "#") then
		kind = "heading"
	elseif M.is_uri(dest) then
		kind, external_dest = "external", dest
	elseif M.is_url(dest) then
		kind, external_dest = "external", "https://" .. dest
	else
		kind, target = "path", resolve_path(dest)
	end

	local function follow_link()
		if kind == "heading" then
			follow_heading_link(dest, t:root())
		elseif kind == "external" then
			open_url(external_dest)
		else
			open_path(target, opts or {})
		end
	end

	local override = config:get().hooks.follow_link

	if override ~= nil then
		local bufnr = api.nvim_get_current_buf()
		local o_opts = opts and vim.deepcopy(opts) or {}
		local o_target = target and vim.deepcopy(target) or {}

		override(
			vim.tbl_extend("error", {
				dest = dest,
				bufnr = bufnr,
				kind = kind,
			}, o_opts, o_target),
			follow_link
		)
	else
		follow_link()
	end
end

return M
