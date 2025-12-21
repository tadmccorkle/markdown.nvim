local api = vim.api
local ts = vim.treesitter

local config = require("markdown.config")
local md_ts = require("markdown.treesitter")
local notify = require("markdown.notify")
local util = require("markdown.util")

local M = {}

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
---@param text string Heading text
---@return string text, string destination
function M.get_heading_link(text)
	local content = util.sanitize(text)
	local dest = md_ts.remove_nodes(content, "markdown_inline", "emphasis_delimiter")
	return content, util.slugify(dest)
end

---@param dest string
---@param root TSNode
local function follow_heading_link(dest, root)
	dest = string.sub(dest, 2)
	for _, match, _ in heading_query:iter_matches(root, 0, 0, -1, { all = true }) do
		local content = md_ts.single_node_from_match(match, 1)
			or md_ts.single_node_from_match(match, 2)
		local heading = md_ts.single_node_from_match(match, 3)
		local in_container = md_ts.find_parent(heading, is_container)
		if not in_container then
			local text = ts.get_node_text(content, 0, nil)
			_, text = M.get_heading_link(text)
			if text == dest then
				local row = heading:start()
				vim.cmd.normal { "m'", bang = true }
				api.nvim_win_set_cursor(0, { row + 1, 0 })
				return
			end
		end
	end
	notify.info("heading not found")
end

---@return string
local function get_sys()
	return vim.loop.os_uname().sysname
end

---@param dest string
---@param sys string
---@return string? error
local function open(dest, sys)
	-- TODO(tad): update to use `vim.system` when nvim 0.9.x support is dropped
	local result
	if sys == "Windows_NT" then
		result = vim.fn.system({ "explorer.exe", dest })
	elseif sys == "Linux" then
		result = vim.fn.system({ "xdg-open", dest })
	elseif sys == "Darwin" then
		result = vim.fn.system({ "open", dest })
	else
		return ("OS '%s' is not supported."):format(sys)
	end

	if vim.v.shell_error > 0 then
		return result
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

	-- try to navigate to headings in the linked file
	local inner_dest
	local s = string.find(path, "%.md#[%w_-]+$")
	if s ~= nil then
		inner_dest = string.sub(path, s + 3)
		path = string.sub(path, 1, s + 2)
	end

	local normalized = vim.fs.normalize(path)
	local is_file = vim.fn.filereadable(normalized) ~= 0
	local is_dir = vim.fn.isdirectory(normalized) ~= 0
	if is_file or is_dir then
		local is_md = string.sub(path, -3) == ".md"
		if opts.use_default_app and not is_md and not is_dir then
			local sys = get_sys()

			local sys_path
			if sys == "Windows_NT" then
				sys_path = string.gsub(normalized, "/", "\\")
			else
				sys_path = normalized
			end

			local err = open(sys_path, sys)
			if err ~= nil then
				notify.error("Open in default app failed. " .. err)
			end
		else
			vim.cmd.edit(path)

			if inner_dest ~= nil then
				local p = ts.get_parser(0, "markdown")
				if p ~= nil then
					follow_heading_link(inner_dest, p:parse()[1]:root())
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
			local sys = get_sys()
			local err = open(dest, sys)
			if err ~= nil then
				notify.error("URL navigation failed. " .. err)
			end
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
