-- Scratch-window presentation shared by the table, cell, and keymap surfaces.
local api = vim.api
local M = {}

-- Center within the tab's usable area, retaining the same margins for all floats.
function M.layout(width, height)
	local top = (vim.o.showtabline == 2
		or (vim.o.showtabline == 1 and #api.nvim_list_tabpages() > 1)) and 1 or 0
	local bottom = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
	width = math.max(1, math.min(width, vim.o.columns - 6))
	height = math.max(1, math.min(height, bottom - top - 4))
	return {
		relative = "editor", width = width, height = height,
		row = math.max(top, top + math.floor((bottom - top - height - 2) / 2)),
		col = math.max(0, math.floor((vim.o.columns - width - 2) / 2)),
	}
end

function M.open(lines, title, width, height, kind)
	local buf = api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "markdown_table_" .. kind
	vim.b[buf].markdown_table_role = kind
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	local opts = M.layout(width, height)
	opts.style, opts.border, opts.title = "minimal", "rounded", title
	local win = api.nvim_open_win(buf, true, opts)
	vim.wo[win].wrap = false
	vim.wo[win].conceallevel = 0
	vim.wo[win].sidescrolloff = 0
	return buf, win
end

function M.dispose(buf, win)
	if win and api.nvim_win_is_valid(win) then pcall(api.nvim_win_close, win, true) end
	if buf and api.nvim_buf_is_valid(buf) then pcall(api.nvim_buf_delete, buf, { force = true }) end
end

function M.map(buf, modes, keys, callback, desc)
	for _, key in ipairs(keys) do
		vim.keymap.set(modes, key, callback, { buffer = buf, silent = true, desc = desc })
	end
end

function M.keymaps(source, mode, namespace)
	local lines, highlights = {}, {}
	for _, keymode in ipairs({ "n", "x", "i" }) do
		local maps = api.nvim_buf_get_keymap(source, keymode)
		table.sort(maps, function(a, b) return a.lhs < b.lhs end)
		for _, mapping in ipairs(maps) do
			if mapping.desc then
				local padding = string.rep(" ", math.max(0, 10 - #mapping.lhs))
				table.insert(lines, keymode .. "  " .. mapping.lhs .. padding .. "  " .. mapping.desc)
				table.insert(highlights, { #lines - 1, 3, 3 + #mapping.lhs })
			end
		end
	end
	table.insert(lines, "")
	table.insert(lines, "?/q/Esc: close")
	table.insert(highlights, { #lines - 1, 0, 7 })
	local width = 32
	for _, line in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(line)) end
	width = math.ceil(width * 1.5)
	local label = mode == "cells" and "cell" or "content"
	local title = " Table Editor Keymaps (" .. label .. " navigation) "
	local buf, win = M.open(lines, title, width, #lines, "help")
	api.nvim_set_hl(0, "MarkdownTableKey", { default = true, link = "Special" })
	for _, range in ipairs(highlights) do
		api.nvim_buf_add_highlight(buf, namespace, "MarkdownTableKey", unpack(range))
	end
	vim.bo[buf].modifiable = false
	return buf, win, width, #lines
end

return M
