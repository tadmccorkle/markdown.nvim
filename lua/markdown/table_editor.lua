local api = vim.api
local tables = require("markdown.table")
local view = require("markdown.table_view")
local layout, float, dispose, map = view.layout, view.open, view.dispose, view.map
local M = {}
local active
local moves = { left = { 0, -1 }, right = { 0, 1 }, up = { -1, 0 }, down = { 1, 0 } }
local source_actions = {
	edit_cell = true, yank_cell = true, row_above = true, row_below = true,
	column_before = true, column_after = true, align_left = true, align_center = true,
	align_right = true, align_none = true,
}

-- Source navigation cannot put a cursor in an omitted trailing cell. Visit the
-- physically present cells, clamping vertical movement to each row's last cell.
local function source_move(model, row, col, name)
	local function columns(r) return math.max(1, #model.starts[r]) end
	col = math.min(col, columns(row))
	if moves[name] then
		row = math.max(1, math.min(#model.rows, row + moves[name][1]))
		col = math.max(1, math.min(columns(row), col + moves[name][2]))
	elseif name == "next" then
		col = col + 1
		if col > columns(row) then row, col = row % #model.rows + 1, 1 end
	else
		col = col - 1
		if col < 1 then
			row = (row - 2) % #model.rows + 1
			col = columns(row)
		end
	end
	return row, col
end

local function warn(message)
	vim.notify("markdown.nvim: " .. message, vim.log.levels.WARN)
end

local function decode(text)
	return text:gsub("\\|", "|"):gsub("<[bB][rR]%s*/?%s*>", "\n")
end

local function encode(lines)
	local result = {}
	for _, text in ipairs(lines) do
		local parts, slashes = {}, 0
		for i = 1, #text do
			local ch = text:sub(i, i)
			if ch == "|" and slashes % 2 == 0 then table.insert(parts, "\\") end
			table.insert(parts, ch)
			slashes = ch == "\\" and slashes + 1 or 0
		end
		table.insert(result, table.concat(parts))
	end
	return vim.trim(table.concat(result, "<br>"))
end

local navigation = {
	{ { "h", "<Left>" }, "left" }, { { "j", "<Down>" }, "down" },
	{ { "k", "<Up>" }, "up" }, { { "l", "<Right>" }, "right" },
	{ { "<Tab>", "w", "e" }, "next" }, { { "<S-Tab>", "b" }, "previous" },
}
local bindings = {
	{ { "i", "<CR>" }, "edit_cell", "Edit cell" },
	{ { "o" }, "row_below", "Insert row below" },
	{ { "O" }, "row_above", "Insert row above" },
	{ { "ci" }, "column_before", "Insert column before" },
	{ { "ca" }, "column_after", "Insert column after" },
	{ { "dd" }, "delete_row", "Delete row (except header)" },
	{ { "dc" }, "delete_column", "Delete column (except last)" },
	{ { "dx" }, "delete_cell", "Clear cell" },
	{ { "." }, "repeat_delete", "Repeat last table deletion" },
	{ { "yy" }, "yank_row", "Yank row" },
	{ { "yc" }, "yank_column", "Yank column" },
	{ { "yx" }, "yank_cell", "Yank cell" },
	{ { "p" }, "paste_after", "Paste after / replace cell" },
	{ { "P" }, "paste_before", "Paste before / replace cell" },
	{ { "al" }, "align_left", "Align column left" },
	{ { "ac" }, "align_center", "Align column center" },
	{ { "ar" }, "align_right", "Align column right" },
	{ { "an" }, "align_none", "Remove explicit alignment" },
	{ { "u" }, "undo", "Undo table operation" },
	{ { "<C-r>" }, "redo", "Redo table operation" },
	{ { "g-" }, "earlier", "Earlier history state (including branches)" },
	{ { "g+" }, "later", "Later history state (including branches)" },
	{ { "<C-g>" }, "toggle_mode", "Toggle cell / content navigation" },
	{ { "s", "<C-y>" }, "save", "Save table and close" },
	{ { "q" }, "close", "Discard table edits" },
	{ { "<Esc>" }, "escape", "Return to cell navigation / discard table edits" },
	{ { "?" }, "help", "Show keymaps" },
}

function M.open(opts)
	opts = opts or {}
	if active then warn("A table editor is already open."); return end
	local source, source_win = api.nvim_get_current_buf(), api.nvim_get_current_win()
	local model, row, col
	if opts.context then model, row, col = unpack(opts.context)
	else model, row, col = tables.context() end
	local creating = not model
	if creating then
		if opts.headless then return end
		local first = api.nvim_win_get_cursor(0)[1] - 1
		local line = api.nvim_buf_get_lines(source, first, first + 1, false)[1]
		-- Replace a blank line; otherwise insert after the current line with spacing.
		model = {
			first = first, last = first + 1, rows = { { "" } }, align = { "none" },
			prefixes = { "" }, continuation = "", tabstop = vim.bo[source].tabstop,
		}
		if vim.trim(line) ~= "" then model.first, model.last = first + 1, first + 1 end
		row, col = 1, 1
	end
	local s = {
		source = source, source_win = source_win, model = model, row = row, col = col,
		tick = api.nvim_buf_get_changedtick(source), headless = opts.headless,
		mode = "cells", creating = creating,
	}
	active = s
	s.group = api.nvim_create_augroup("markdown.table_editor", { clear = true })
	s.ns = api.nvim_create_namespace("markdown.table_editor")

	-- Source ranges and parsed cursor positions are immutable session metadata;
	-- history only needs editable data and the selected cell.
	local function model_data()
		return { rows = model.rows, align = model.align, prefixes = model.prefixes }
	end
	local function state()
		return { data = model_data(), row = s.row, col = s.col }
	end
	s.history = require("markdown.table_history").new(state())

	local function title()
		return s.mode == "cells" and " Edit Table " or " Edit Table (content) "
	end

	function s.close()
		if s.closed then return end
		s.closed, active = true, nil
		api.nvim_del_augroup_by_id(s.group)
		vim.cmd("stopinsert")
		dispose(s.help_buf, s.help_win)
		dispose(s.cell_buf, s.cell_win)
		dispose(s.buf, s.win)
		if api.nvim_win_is_valid(source_win) then api.nvim_set_current_win(source_win) end
	end

	function s.highlight()
		if s.headless then return end
		api.nvim_buf_clear_namespace(s.buf, s.ns, 0, -1)
		local line = s.row == 1 and 1 or s.row + 1
		local bound = s.bounds[s.row][s.col]
		api.nvim_buf_add_highlight(s.buf, s.ns, "Visual", line - 1, bound.first, bound.last)
	end

	function s.sync_cursor()
		if s.headless or s.rendering or s.closed then return end
		local cursor = api.nvim_win_get_cursor(s.win)
		s.row = math.min(#model.rows, math.max(1, cursor[1] - 1))
		local distance = math.huge
		for i, bound in ipairs(s.bounds[s.row]) do
			local gap = math.max(bound.first - cursor[2], cursor[2] - bound.last, 0)
			if gap < distance then s.col, distance = i, gap end
		end
		s.highlight()
	end

	function s.select()
		if s.headless then return end
		s.rendering = true
		local line = s.row == 1 and 1 or s.row + 1
		local start = s.positions[s.row][s.col]
		api.nvim_win_set_cursor(s.win, { line, start })
		-- Prefer showing the entire content, not a trailing fragment of a wide cell.
		local text = s.lines[line]
		local left = vim.fn.strdisplaywidth(text:sub(1, start))
		local right = vim.fn.strdisplaywidth(text:sub(1, s.bounds[s.row][s.col].text_end))
		local width = api.nvim_win_get_width(s.win)
		api.nvim_win_call(s.win, function()
			local view = vim.fn.winsaveview()
			if right - left >= width or left < view.leftcol then
				view.leftcol = left
			elseif right >= view.leftcol + width then
				view.leftcol = math.max(0, right - width + 1)
			end
			vim.fn.winrestview(view)
		end)
		s.rendering = false
		s.highlight()
	end

	function s.render()
		if s.headless then return end
		s.rendering = true
		s.lines, s.positions, s.bounds = tables.render(model, true)
		local width = 20
		for _, line in ipairs(s.lines) do width = math.max(width, vim.fn.strdisplaywidth(line)) end
		s.width, s.height = width, #s.lines
		if not s.buf then
			s.buf, s.win = float(s.lines, title(), width, #s.lines, "editor")
		else
			vim.bo[s.buf].modifiable = true
			api.nvim_buf_set_lines(s.buf, 0, -1, false, s.lines)
			local config = layout(width, #s.lines)
			config.title = title()
			api.nvim_win_set_config(s.win, config)
		end
		vim.bo[s.buf].modifiable = false
		s.rendering = false
		s.select()
	end

	function s.change(callback)
		s.sync_cursor()
		local before = vim.deepcopy(model_data())
		callback()
		local changed = not vim.deep_equal(before, model_data())
		if changed then s.history.push(state()) end
		s.render()
		return changed
	end

	function s.move(dr, dc)
		s.sync_cursor()
		s.row = math.max(1, math.min(#model.rows, s.row + dr))
		s.col = math.max(1, math.min(#model.align, s.col + dc))
		s.select()
	end

	function s.tab(delta)
		s.sync_cursor()
		local index = ((s.row - 1) * #model.align + s.col - 1 + delta)
			% (#model.rows * #model.align)
		s.row, s.col = math.floor(index / #model.align) + 1, index % #model.align + 1
		s.select()
	end

	local function add_columns(count)
		for _ = #model.align + 1, count do
			table.insert(model.align, "none")
			for _, cells in ipairs(model.rows) do table.insert(cells, "") end
		end
	end

	local function add_row(index, cells)
		cells = vim.deepcopy(cells or {})
		add_columns(#cells)
		for i = #cells + 1, #model.align do cells[i] = "" end
		table.insert(model.rows, index, cells)
		table.insert(model.prefixes, index, model.continuation)
	end

	function s.insert_row(above)
		s.change(function()
			s.row = math.max(2, s.row + (above and 0 or 1))
			add_row(s.row)
		end)
	end

	function s.insert_column(before)
		s.change(function()
			s.col = s.col + (before and 0 or 1)
			table.insert(model.align, s.col, "none")
			for _, cells in ipairs(model.rows) do table.insert(cells, s.col, "") end
		end)
	end

	function s.yank(kind, count)
		s.sync_cursor()
		local value
		if kind == "row" and (count or 1) > 1 then
			value = {}
			for i = s.row, math.min(#model.rows, s.row + count - 1) do
				table.insert(value, vim.deepcopy(model.rows[i]))
			end
			kind = "rows"
		elseif kind == "row" then value = vim.deepcopy(model.rows[s.row])
		elseif kind == "column" then
			value = {}
			for i, cells in ipairs(model.rows) do value[i] = cells[s.col] end
		else value = model.rows[s.row][s.col] end
		s.register = { kind = kind, value = value, align = model.align[s.col] }
		if kind == "cell" then vim.fn.setreg('"', decode(value), "v") end
	end

	function s.delete(kind, count)
		s.sync_cursor()
		if kind == "row" and s.row == 1 then warn("The header row cannot be deleted."); return end
		if kind == "column" and #model.align == 1 then
			warn("The last column cannot be deleted."); return
		end
		count = kind == "row" and math.max(1, count or 1) or 1
		local requested = count
		count = kind == "row" and math.min(count, #model.rows - s.row + 1) or count
		s.yank(kind, count)
		local changed = s.change(function()
			if kind == "row" then
				for _ = 1, count do
					table.remove(model.rows, s.row)
					table.remove(model.prefixes, s.row)
				end
				s.row = math.min(s.row, #model.rows)
			elseif kind == "column" then
				table.remove(model.align, s.col)
				for _, cells in ipairs(model.rows) do table.remove(cells, s.col) end
				s.col = math.min(s.col, #model.align)
			else model.rows[s.row][s.col] = "" end
		end)
		if changed then
			s.last_delete = { kind = kind, count = requested }
		end
	end

	function s.repeat_delete()
		if s.last_delete then
			local count = vim.v.count ~= 0 and vim.v.count or s.last_delete.count
			s.delete(s.last_delete.kind, count)
		end
	end

	-- Visual line ranges use preview lines; the delimiter is never a data row.
	function s.visual_rows(kind, first, last)
		first, last = math.min(first, last), math.max(first, last)
		local start_row, end_row
		for i = 1, #model.rows do
			local line = i == 1 and 1 or i + 1
			if line >= first and line <= last and (kind ~= "delete" or i > 1) then
				start_row, end_row = start_row or i, i
			end
		end
		if not start_row then return end
		s.sync_cursor()
		s.row = start_row
		s.select()
		if kind == "delete" then s.delete("row", end_row - start_row + 1)
		else s.yank("row", end_row - start_row + 1) end
	end

	function s.paste(before)
		if not s.register then return end
		local reg = s.register
		s.change(function()
			if reg.kind == "row" then
				s.row = math.max(2, s.row + (before and 0 or 1))
				add_row(s.row, reg.value)
			elseif reg.kind == "rows" then
				s.row = math.max(2, s.row + (before and 0 or 1))
				for i, cells in ipairs(reg.value) do add_row(s.row + i - 1, cells) end
			elseif reg.kind == "column" then
				s.col = s.col + (before and 0 or 1)
				while #model.rows < #reg.value do add_row(#model.rows + 1) end
				table.insert(model.align, s.col, reg.align)
				for i, cells in ipairs(model.rows) do
					table.insert(cells, s.col, reg.value[i] or "")
				end
			else model.rows[s.row][s.col] = reg.value end
		end)
	end

	function s.align(value)
		s.change(function() model.align[s.col] = value end)
	end

	function s.restore(value)
		if not value then return end
		model.rows, model.align, model.prefixes = value.data.rows, value.data.align, value.data.prefixes
		s.row, s.col = value.row, value.col
		s.render()
	end
	function s.undo() s.restore(s.history.undo()) end
	function s.redo() s.restore(s.history.redo()) end
	function s.earlier() s.restore(s.history.earlier(-1)) end
	function s.later() s.restore(s.history.earlier(1)) end

	function s.help()
		if s.help_win and api.nvim_win_is_valid(s.help_win) then
			api.nvim_set_current_win(s.help_win)
			return
		end
		local from = api.nvim_get_current_win()
		s.help_buf, s.help_win, s.help_width, s.help_height =
			view.keymaps(api.nvim_get_current_buf(), s.mode, s.ns)
		map(s.help_buf, "n", { "?", "q", "<Esc>" }, function()
			dispose(s.help_buf, s.help_win)
			s.help_buf, s.help_win = nil, nil
			if api.nvim_win_is_valid(from) then api.nvim_set_current_win(from) end
		end, "Close keymap help")
	end

	function s.commit_cell(lines)
		local row, col = s.cell_row, s.cell_col
		-- Preserve exact Markdown spelling when the decoded editor text is unchanged.
		local text = vim.deep_equal(lines, s.cell_lines) and s.cell_original or encode(lines)
		s.cell_changed = s.change(function()
			model.rows[row][col] = text
			s.row, s.col = row, col
		end)
	end

	function s.after_cell()
		if s.closed or s.cell_buf then return end
		vim.cmd("stopinsert")
		if s.headless then
			if not s.cell_changed then s.close()
			elseif not s.save() then s.mount() end
		else
			api.nvim_set_current_win(s.win)
			s.select()
		end
	end

	-- Every cell dismissal accepts. Table-level undo can revert an accidental edit.
	function s.finish_cell()
		if not s.cell_buf then return end
		local buf, win = s.cell_buf, s.cell_win
		s.commit_cell(api.nvim_buf_get_lines(buf, 0, -1, false))
		s.cell_buf, s.cell_win = nil, nil
		dispose(buf, win)
		s.after_cell()
	end

	function s.resize_cell()
		if not s.cell_win or not api.nvim_win_is_valid(s.cell_win) then return end
		s.cell_height = math.min(10, api.nvim_buf_line_count(s.cell_buf))
		api.nvim_win_set_config(s.cell_win, layout(s.cell_width, s.cell_height))
	end

	function s.edit_cell()
		if s.cell_buf then return end
		s.sync_cursor()
		s.cell_row, s.cell_col = s.row, s.col
		s.cell_original = model.rows[s.row][s.col]
		local lines = vim.split(decode(s.cell_original), "\n", { plain = true })
		s.cell_lines = vim.deepcopy(lines)
		local width = 64
		for _, line in ipairs(lines) do width = math.max(width, vim.fn.strdisplaywidth(line) + 4) end
		s.cell_width, s.cell_height = width, math.min(10, #lines)
		s.cell_buf, s.cell_win = float(lines, " Edit Cell ", width, s.cell_height, "cell")
		local cell_buf, resize_pending = s.cell_buf, false
		api.nvim_buf_attach(cell_buf, false, {
			on_lines = function()
				if resize_pending then return end
				resize_pending = true
				-- Buffer callbacks run under textlock; defer window changes.
				vim.schedule(function()
					resize_pending = false
					if s.cell_buf == cell_buf and not s.closed then s.resize_cell() end
				end)
			end,
		})
		map(s.cell_buf, { "n", "i" }, { "<C-y>", "<CR>", "<C-s>", "<Esc>" },
			s.finish_cell, "Accept cell and close")
		for _, key in ipairs({ "<S-CR>", "<C-j>" }) do
			-- Nonrecursive RHS uses native Enter instead of the confirmation mapping.
			vim.keymap.set("i", key, "<CR>", {
				buffer = s.cell_buf, desc = "Insert cell newline",
			})
			vim.keymap.set("n", key, "a<CR><Esc>", {
				buffer = s.cell_buf, desc = "Insert cell newline",
			})
		end
		map(s.cell_buf, "n", { "?" }, s.help, "Show keymaps")
		api.nvim_create_autocmd("WinClosed", {
			group = s.group, pattern = tostring(s.cell_win), once = true,
			callback = function()
				if s.closed or s.cell_buf ~= cell_buf then return end
				-- Capture before bufhidden=wipe destroys the externally closed cell buffer.
				s.commit_cell(api.nvim_buf_get_lines(cell_buf, 0, -1, false))
				s.cell_buf, s.cell_win = nil, nil
				-- Finish focusing/saving after Neovim has completed the window close.
				vim.schedule(s.after_cell)
			end,
		})
		api.nvim_win_set_cursor(s.cell_win, { #lines, #lines[#lines] })
		vim.cmd("startinsert!")
	end

	function s.export()
		local buf = api.nvim_create_buf(true, true)
		local lines = tables.render(model, true)
		api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].filetype = "markdown"
		vim.b[buf].markdown_table_role = "export"
		for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
			if api.nvim_win_get_config(win).relative == "" then
				api.nvim_set_current_win(win)
				break
			end
		end
		vim.cmd("botright split")
		api.nvim_win_set_buf(0, buf)
		return buf
	end

	function s.save()
		if not api.nvim_buf_is_valid(source) or not api.nvim_buf_is_loaded(source) then
			warn("Source buffer is unavailable; use :MDTableExport to recover staged edits.")
			return false
		end
		if api.nvim_buf_get_changedtick(source) ~= s.tick then
			warn("Source buffer changed; use :MDTableExport to recover staged edits.")
			return false
		end
		if not vim.bo[source].modifiable or vim.bo[source].readonly then
			warn("Source buffer is not writable; use :MDTableExport to recover staged edits.")
			return false
		end
		local lines, positions = tables.render(model)
		if creating then
			local count = api.nvim_buf_line_count(source)
			if model.first > 0 then
				local prev = api.nvim_buf_get_lines(source, model.first - 1, model.first, false)[1]
				if prev and vim.trim(prev) ~= "" then table.insert(lines, 1, "") end
			end
			if model.last < count then
				local next_line = api.nvim_buf_get_lines(source, model.last, model.last + 1, false)[1]
				if next_line and vim.trim(next_line) ~= "" then table.insert(lines, "") end
			end
		end
		local old = api.nvim_buf_get_lines(source, model.first, model.last, false)
		if not vim.deep_equal(lines, old) then
			api.nvim_buf_set_lines(source, model.first, model.last, false, lines)
		end
		s.close()
		if s.headless and api.nvim_win_is_valid(source_win)
			and api.nvim_win_get_buf(source_win) == source then
			api.nvim_win_set_cursor(source_win, {
				model.first + (s.row == 1 and 1 or s.row + 1), positions[s.row][s.col],
			})
		end
		return true
	end

	function s.toggle_mode()
		s.sync_cursor()
		s.mode = s.mode == "cells" and "contents" or "cells"
		for _, entry in ipairs(navigation) do
			for _, key in ipairs(entry[1]) do
				if s.mode == "contents" then
					vim.keymap.del("n", key, { buffer = s.buf })
				else
					map(s.buf, "n", { key }, function() s.run(entry[2]) end, "Cell " .. entry[2])
				end
			end
		end
		local config = { title = title() }
		api.nvim_win_set_config(s.win, config)
		if s.mode == "cells" then s.select() end
	end

	function s.escape()
		if s.mode == "contents" then s.toggle_mode() else s.close() end
	end

	function s.run(name)
		if moves[name] then s.move(unpack(moves[name]))
		elseif name == "next" or name == "previous" then s.tab(name == "next" and 1 or -1)
		elseif name == "row_above" or name == "row_below" then s.insert_row(name == "row_above")
		elseif name == "column_before" or name == "column_after" then
			s.insert_column(name == "column_before")
		elseif name:match("^yank_") then s.yank(name:sub(6))
		elseif name:match("^delete_") then s.delete(name:sub(8), vim.v.count1)
		elseif name:match("^align_") then s.align(name:sub(7))
		elseif name == "paste_before" or name == "paste_after" then s.paste(name == "paste_before")
		elseif s[name] then return s[name]() end
	end

	api.nvim_create_autocmd("VimResized", {
		group = s.group,
		callback = function()
			for _, kind in ipairs({ "", "cell_", "help_" }) do
				local win = s[kind .. "win"]
				if win and api.nvim_win_is_valid(win) then
					api.nvim_win_set_config(win, layout(s[kind .. "width"], s[kind .. "height"]))
				end
			end
		end,
	})

	function s.mount()
		s.headless = false
		s.render()
		for _, entry in ipairs(navigation) do
			map(s.buf, "n", entry[1], function() s.run(entry[2]) end, "Cell " .. entry[2])
		end
		for _, entry in ipairs(bindings) do
			map(s.buf, "n", entry[1], function() s.run(entry[2]) end, entry[3])
		end
		for _, key in ipairs({ "d", "x", "y" }) do
			vim.keymap.set("x", key, function()
				if vim.fn.mode() ~= "V" then return key end
				local first = vim.fn.line("v")
				local last = api.nvim_win_get_cursor(s.win)[1]
				local kind = key == "y" and "yank" or "delete"
				return "<Esc><Cmd>lua require('markdown.table_editor').visual_rows('"
					.. kind .. "'," .. first .. "," .. last .. ")<CR>"
			end, {
				buffer = s.buf, expr = true, silent = true,
				desc = key == "y" and "Yank selected rows (Visual line)"
					or "Delete selected rows (Visual line, except header)",
			})
		end
		api.nvim_buf_create_user_command(s.buf, "MDTableExport", s.export, {
			desc = "Export staged table to a scratch buffer",
		})
		api.nvim_create_autocmd("CursorMoved", {
			group = s.group, buffer = s.buf, callback = s.sync_cursor,
		})
		api.nvim_create_autocmd("WinClosed", {
			group = s.group, pattern = tostring(s.win), once = true, callback = s.close,
		})
	end
	if not s.headless then s.mount() end
	return s
end

function M.visual_rows(kind, first, last)
	if active and api.nvim_get_current_buf() == active.buf then
		active.visual_rows(kind, first, last)
	end
end

function M.export()
	if active then return active.export() end
end

---Shared actions for <Plug> maps in the editor and in source Markdown buffers.
function M.action(name)
	if active then
		if api.nvim_get_current_buf() == active.buf then return active.run(name) end
		warn("Return to the open table editor first.")
		return
	end
	local model, row, col = tables.context()
	if not model then return end
	if moves[name] or name == "next" or name == "previous" then
		row, col = source_move(model, row, col, name)
		local line = model.first + (row == 1 and 1 or row + 1)
		api.nvim_win_set_cursor(0, { line, model.starts[row][col] or 0 })
		return
	end
	if not source_actions[name] then return end
	local s = M.open({ headless = true, context = { model, row, col } })
	if not s then return end
	s.run(name)
	if name:match("^yank_") then s.close()
	elseif name ~= "edit_cell" and not s.save() then s.mount() end
	return s
end

return M
