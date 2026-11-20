local api = vim.api
local tbl = require("markdown.table")
require("luassert")

local function new_md_buf(lines)
	local buf = api.nvim_create_buf(true, true)
	api.nvim_win_set_buf(0, buf)
	vim.bo[buf].filetype = "markdown"
	api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	return buf
end

local function assert_buf_eq(buf, lines)
	assert.are.same(lines, api.nvim_buf_get_lines(buf, 0, -1, false))
end

local function normal(keys)
	vim.cmd("normal " .. api.nvim_replace_termcodes(keys, true, false, true))
end

local basic = { "| a | b |", "| - | - |", "| c | d |" }
local formatted = { "| a   | b   |", "| --- | --- |", "| c   | d   |" }

describe("tables", function()
	before_each(function()
		require("markdown.config"):reset()
		require("markdown").setup()
	end)

	it("formats aligned columns including headers and is idempotent", function()
		local buf = new_md_buf({ "a | b | c | d", ":- | -: | :-: | -", "long | x | z | text" })
		tbl.format(0, -1)
		assert_buf_eq(buf, {
			"| a    |    b |   c   | d    |",
			"| :--- | ---: | :---: | ---- |",
			"| long |    x |   z   | text |",
		})
		local tick = api.nvim_buf_get_changedtick(buf)
		tbl.format(0, -1)
		assert.are.equal(tick, api.nvim_buf_get_changedtick(buf))
	end)

	it("preserves escaped pipes and inline Markdown, pads irregular rows", function()
		local buf = new_md_buf({ "| a | b |", "| - | - |", "| `x\\|y` |", "| z | q | extra |" })
		tbl.format(0, -1)
		assert_buf_eq(buf, {
			"| a      | b   |       |", "| ------ | --- | ----- |",
			"| `x\\|y` |     |       |", "| z      | q   | extra |",
		})
	end)

	it("uses Unicode display widths and expands tabs", function()
		local buf = new_md_buf({ "| 界 | x |", "| - | - |", "| abcd | x\ty |" })
		vim.bo[buf].tabstop = 4
		tbl.format(0, -1)
		assert_buf_eq(buf, {
			"| 界   | x     |", "| ---- | ----- |", "| abcd | x   y |",
		})
	end)

	it("selects current, intersecting range, and all tables but not code", function()
		local lines = vim.list_extend(vim.deepcopy(basic), { "", "```", unpack(basic) })
		vim.list_extend(lines, { "```", "", unpack(basic) })
		local buf = new_md_buf(lines)
		api.nvim_win_set_cursor(0, { 2, 0 })
		vim.cmd("MDTableFormat")
		for i = 1, 3 do lines[i] = formatted[i] end
		assert_buf_eq(buf, lines)
		vim.cmd("11,11MDTableFormat")
		for i = 1, 3 do lines[10 + i] = formatted[i] end
		assert_buf_eq(buf, lines)
		vim.cmd("MDTableFormatAll")
		assert_buf_eq(buf, lines)
	end)

	it("does nothing away from tables", function()
		local buf = new_md_buf({ "plain text", "", unpack(basic) })
		local tick = api.nvim_buf_get_changedtick(buf)
		tbl.format()
		local editor = tbl.edit()
		assert.are.same({ { "" } }, editor.model.rows)
		editor.close()
		assert.are.equal(tick, api.nvim_buf_get_changedtick(buf))
	end)

	it("preserves list and quote prefixes", function()
		local buf = new_md_buf({
			"> | a | b |", "> | - | - |", "> | c | d |", "",
			"- | a | b |", "  | - | - |", "  | c | d |",
		})
		tbl.format(0, -1)
		assert_buf_eq(buf, {
			"> | a   | b   |", "> | --- | --- |", "> | c   | d   |", "",
			"- | a   | b   |", "  | --- | --- |", "  | c   | d   |",
		})
	end)

	it("provides unconditional Plug mappings for custom keybindings", function()
		vim.cmd("runtime plugin/markdown.lua")
		local buf = new_md_buf(basic)
		vim.fn.maparg("<Plug>(markdown_table_format_all)", "n", false, true).callback()
		assert_buf_eq(buf, formatted)
		assert.is_function(vim.fn.maparg("<Plug>(markdown_table_edit)", "n", false, true).callback)
	end)

	it("formats all tables as one undo operation", function()
		local lines = vim.list_extend(vim.deepcopy(basic), { "", unpack(basic) })
		local buf = new_md_buf(lines)
		-- Separate fixture setup from the user operation in the undo history.
		vim.cmd("let &undolevels = &undolevels")
		tbl.format(0, -1)
		vim.cmd("undo")
		assert_buf_eq(buf, lines)
	end)
end)

describe("table editor", function()
	local session
	before_each(function()
		new_md_buf(basic)
	end)
	after_each(function()
		if session and not session.closed then session.close() end
		session = nil
	end)

	it("opens on cursor cell, navigates headers, clamps and wraps", function()
		api.nvim_win_set_cursor(0, { 3, 6 })
		session = tbl.edit()
		assert.are.same({ 2, 2 }, { session.row, session.col })
		session.move(-1, -1)
		assert.are.same({ 1, 1 }, { session.row, session.col })
		session.move(-1, -1)
		assert.are.same({ 1, 1 }, { session.row, session.col })
		session.tab(-1)
		assert.are.same({ 2, 2 }, { session.row, session.col })
		session.tab(1)
		assert.are.same({ 1, 1 }, { session.row, session.col })
		assert.is_false(vim.bo[session.buf].modifiable)
	end)

	it("stages cell changes, accepts dismissal, and supports undoing the cell edit", function()
		local buf = api.nvim_get_current_buf()
		session = tbl.edit()
		session.edit_cell()
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "x|y\\|z" })
		session.finish_cell()
		assert.are.equal("x\\|y\\|z", session.model.rows[1][1])
		assert_buf_eq(buf, basic)
		session.edit_cell()
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "dismissed" })
		vim.fn.maparg("<Esc>", "i", false, true).callback()
		assert.are.equal("dismissed", session.model.rows[1][1])
		session.undo()
		assert.are.equal("x\\|y\\|z", session.model.rows[1][1])
		assert.is_true(session.save())
		assert.are.equal("x\\|y\\|z", tbl.tables(buf)[1].rows[1][1])
	end)

	it("encodes multiline cell edits and decodes pipes and breaks on reopening", function()
		session = tbl.edit()
		session.edit_cell()
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "one|two", "three" })
		session.finish_cell()
		assert.is_nil(session.cell_buf)
		assert.are.equal("one\\|two<br>three", session.model.rows[1][1])
		session.edit_cell()
		assert_buf_eq(session.cell_buf, { "one|two", "three" })
	end)

	it("inserts body rows and columns before and after selection", function()
		session = tbl.edit()
		session.insert_row(true)
		assert.are.equal(2, session.row)
		session.insert_row(false)
		assert.are.equal(3, session.row)
		session.insert_column(true)
		assert.are.equal(1, session.col)
		session.insert_column(false)
		assert.are.equal(2, session.col)
		assert.are.same({ "", "", "a", "b" }, session.model.rows[1])
		assert.are.equal(4, #session.model.rows)
		assert.is_true(session.save())
	end)

	it("cancels without source changes and wipes both floats", function()
		local buf = api.nvim_get_current_buf()
		session = tbl.edit()
		local preview = session.buf
		session.edit_cell()
		local cell = session.cell_buf
		session.close()
		assert_buf_eq(buf, basic)
		assert.is_false(api.nvim_buf_is_valid(preview))
		assert.is_false(api.nvim_buf_is_valid(cell))
	end)

	it("cleans up when its float is externally closed", function()
		session = tbl.edit()
		local buf = session.buf
		api.nvim_win_close(session.win, true)
		assert.is_true(session.closed)
		assert.is_false(api.nvim_buf_is_valid(buf))
	end)

	it("refuses to overwrite source edits or nonmodifiable buffers", function()
		local buf = api.nvim_get_current_buf()
		session = tbl.edit()
		vim.bo[buf].modifiable = false
		assert.is_false(session.save())
		vim.bo[buf].modifiable = true
		api.nvim_buf_set_lines(buf, 0, 1, false, { "| changed | b |" })
		assert.is_false(session.save())
		assert.is_false(session.closed == true)
		assert.are.equal("| changed | b |", api.nvim_buf_get_lines(buf, 0, 1, false)[1])
	end)

	it("saves as one undo operation", function()
		local buf = api.nvim_get_current_buf()
		vim.cmd("let &undolevels = &undolevels")
		session = tbl.edit()
		session.insert_row(false)
		session.insert_column(false)
		assert.is_true(session.save())
		vim.cmd("undo")
		assert_buf_eq(buf, basic)
	end)

	it("inserts the first body row into a header-only table", function()
		local buf = new_md_buf({ "| a | b |", "| - | - |" })
		session = tbl.edit()
		session.insert_row(false)
		assert.are.equal(2, session.row)
		assert.is_true(session.save())
		assert_buf_eq(buf, { "| a   | b   |", "| --- | --- |", "|     |     |" })
	end)

	it("inserts nested rows with continuation prefixes", function()
		local buf = new_md_buf({ "- | a | b |", "  | - | - |", "  | c | d |" })
		session = tbl.edit()
		session.insert_row(true)
		session.save()
		assert_buf_eq(buf, {
			"- | a   | b   |", "  | --- | --- |", "  |     |     |", "  | c   | d   |",
		})
	end)

	it("allows a cell to be reopened after external closure", function()
		session = tbl.edit()
		session.edit_cell()
		local cell = session.cell_buf
		api.nvim_win_close(session.cell_win, true)
		assert.is_nil(session.cell_buf)
		assert.is_false(api.nvim_buf_is_valid(cell))
		session.edit_cell()
		assert.is_not_nil(session.cell_buf)
		session.finish_cell()
	end)

	it("refuses saving a wiped source and still closes cleanly", function()
		local buf = api.nvim_get_current_buf()
		session = tbl.edit()
		assert.are.equal(buf, session.source)
		api.nvim_set_current_win(session.source_win)
		api.nvim_buf_delete(buf, { force = true })
		assert.is_false(api.nvim_buf_is_loaded(buf))
		assert.is_false(session.save())
		session.close()
		assert.is_false(api.nvim_buf_is_valid(session.buf))
	end)

	it("bounds the preview on small terminals", function()
		local columns, lines = vim.o.columns, vim.o.lines
		vim.o.columns, vim.o.lines = 30, 12
		session = tbl.edit()
		local config = api.nvim_win_get_config(session.win)
		vim.o.columns, vim.o.lines = columns, lines
		assert.is_true(config.width <= 26)
		assert.is_true(config.height <= 6)
	end)

	it("identifies floats and keeps keymaps exclusively in help", function()
		session = tbl.edit()
		assert.are.equal("markdown_table_editor", vim.bo[session.buf].filetype)
		assert_buf_eq(session.buf, formatted)
		session.help()
		assert.are.equal("markdown_table_help", vim.bo[session.help_buf].filetype)
		local help = table.concat(api.nvim_buf_get_lines(session.help_buf, 0, -1, false), "\n")
		assert.is_not_nil(help:find("Insert column before", 1, true))
		vim.fn.maparg("?", "n", false, true).callback()
		session.edit_cell()
		assert.are.equal("markdown_table_cell", vim.bo[session.cell_buf].filetype)
		assert.are.equal("cell", vim.b[session.cell_buf].markdown_table_role)
	end)

	it("retains branches in operation-level undo and redo", function()
		session = tbl.edit()
		session.insert_row(false)
		session.insert_column(false)
		session.undo()
		assert.are.equal(2, #session.model.align)
		session.align("right")
		assert.are.equal(4, #session.history.nodes)
		session.undo()
		session.redo()
		assert.are.equal("right", session.model.align[1])
		session.earlier()
		assert.are.equal(3, #session.model.align)
		session.undo()
		session.redo()
		assert.are.equal(3, #session.model.align)
		session.later()
		assert.are.equal("right", session.model.align[1])
	end)

	it("moves rows and columns with typed delete and paste", function()
		session = tbl.edit()
		session.move(1, 0)
		session.delete("row")
		assert.are.same({ { "a", "b" } }, session.model.rows)
		session.paste(true)
		assert.are.same({ { "a", "b" }, { "c", "d" } }, session.model.rows)
		session.move(-1, 0)
		session.align("right")
		session.delete("column")
		session.paste(false)
		assert.are.same({ { "b", "a" }, { "d", "c" } }, session.model.rows)
		assert.are.same({ "none", "right" }, session.model.align)
		session.undo()
		assert.are.same({ { "b" }, { "d" } }, session.model.rows)
	end)

	it("protects the header and last column, but allows yanking them", function()
		session = tbl.edit()
		session.delete("row")
		assert.are.equal(2, #session.model.rows)
		assert.are.equal(1, #session.history.nodes)
		session.yank("row")
		session.paste(true)
		assert.are.same({ "a", "b" }, session.model.rows[2])
		session.delete("column")
		session.delete("column")
		assert.are.equal(1, #session.model.align)
	end)

	it("clears, yanks and pastes cells without inserting cells", function()
		session = tbl.edit()
		session.delete("cell")
		assert.are.equal("", session.model.rows[1][1])
		session.move(1, 1)
		session.paste(false)
		assert.are.same({ "c", "a" }, session.model.rows[2])
		session.yank("cell")
		assert.are.equal("a", vim.fn.getreg('"'))
	end)

	it("fills dimensions when pasting previously yanked rows or columns", function()
		session = tbl.edit()
		session.yank("row")
		session.delete("column")
		-- Deletion updates the register, so keep the older row explicitly.
		session.register = { kind = "row", value = { "a", "b", "extra" } }
		session.paste(false)
		assert.are.equal(3, #session.model.align)
		assert.are.same({ "a", "b", "extra" }, session.model.rows[2])
		session.register = { kind = "column", value = { "h", "1", "2", "3" }, align = "center" }
		session.paste(false)
		assert.are.equal(4, #session.model.rows)
		assert.are.equal("center", session.model.align[2])
	end)

	it("tracks arbitrary cursor moves and exposes native content navigation", function()
		session = tbl.edit()
		api.nvim_win_set_cursor(session.win, { 3, 10 })
		api.nvim_exec_autocmds("CursorMoved", { buffer = session.buf })
		assert.are.same({ 2, 2 }, { session.row, session.col })
		session.toggle_mode()
		assert.are.equal("contents", session.mode)
		assert.are.equal("", vim.fn.maparg("h", "n"))
		assert.are.equal(1, vim.fn.maparg("ci", "n", false, true).buffer)
		assert.is_false(vim.bo[session.buf].modifiable)
		api.nvim_win_set_cursor(session.win, { 1, 0 })
		session.align("center")
		assert.are.equal("center", session.model.align[1])
		session.escape()
		assert.are.equal("cells", session.mode)
		assert.is_false(session.closed == true)
		assert.are.equal(1, vim.fn.maparg("h", "n", false, true).buffer)
	end)

	it("exports staged edits after a conflict without touching the source", function()
		local source = api.nvim_get_current_buf()
		session = tbl.edit()
		session.insert_row(false)
		api.nvim_buf_set_lines(source, 0, 1, false, { "changed" })
		assert.is_false(session.save())
		local export = session.export()
		assert.are.equal("markdown", vim.bo[export].filetype)
		assert.are.equal("export", vim.b[export].markdown_table_role)
		assert.are.equal(4, api.nvim_buf_line_count(export))
		assert.are.equal("changed", api.nvim_buf_get_lines(source, 0, 1, false)[1])
		local win = api.nvim_get_current_win()
		api.nvim_win_close(win, true)
		api.nvim_buf_delete(export, { force = true })
	end)

	it("creates a one-header one-column table without replacing prose", function()
		local source = new_md_buf({ "paragraph", "next paragraph" })
		session = tbl.edit()
		assert.are.same({ { "" } }, session.model.rows)
		assert.is_true(session.save())
		assert_buf_eq(source, { "paragraph", "", "|     |", "| --- |", "", "next paragraph" })
	end)

	it("centers the preview after growth and resize", function()
		session = tbl.edit()
		session.insert_column(false)
		local config = api.nvim_win_get_config(session.win)
		assert.are.equal(math.floor((vim.o.columns - config.width - 2) / 2), config.col)
		assert.are.equal(3, config.height)
		api.nvim_exec_autocmds("VimResized", {})
		assert.are.equal(config.col, api.nvim_win_get_config(session.win).col)
	end)

	it("shows the beginning of oversized cells on horizontal navigation", function()
		new_md_buf({ "| a | " .. string.rep("界", 100) .. " |", "| - | - |" })
		session = tbl.edit()
		session.move(0, 1)
		local start = session.positions[1][2]
		local left = vim.fn.strdisplaywidth(session.lines[1]:sub(1, start))
		api.nvim_win_call(session.win, function()
			assert.are.equal(left, vim.fn.winsaveview().leftcol)
		end)
	end)

	it("supports source-buffer Plug navigation, editing, insertion and copying", function()
		vim.cmd("runtime plugin/markdown.lua")
		local source = api.nvim_get_current_buf()
		local function action(name)
			return vim.fn.maparg("<Plug>(markdown_table_" .. name .. ")", "n", false, true).callback()
		end
		action("next")
		action("down")
		assert.are.same({ 3, 5 }, api.nvim_win_get_cursor(0))
		action("yank_cell")
		assert.are.equal("d", vim.fn.getreg('"'))
		assert_buf_eq(source, basic)
		session = tbl.action("edit_cell")
		assert.is_true(session.headless)
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "changed", "cell" })
		session.finish_cell()
		assert.is_true(session.closed)
		assert.are.equal("changed<br>cell", tbl.tables(source)[1].rows[2][2])
		action("column_before")
		assert.are.equal(3, #tbl.tables(source)[1].align)
	end)

	it("promotes a conflicted source cell edit to a recoverable table editor", function()
		local source = api.nvim_get_current_buf()
		session = tbl.action("edit_cell")
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "recover me" })
		api.nvim_buf_set_lines(source, 0, 1, false, { "conflict" })
		session.finish_cell()
		assert.is_false(session.headless)
		assert.is_true(api.nvim_win_is_valid(session.win))
		assert.are.equal("recover me", session.model.rows[1][1])
	end)

	it("repeats row, column and cell deletions with dot", function()
		new_md_buf({ "| a | b | c |", "| - | - | - |", "| 1 | 2 | 3 |", "| 4 | 5 | 6 |" })
		session = tbl.edit()
		normal("jdd.")
		assert.are.same({ { "a", "b", "c" } }, session.model.rows)
		session.undo()
		assert.are.same({ "4", "5", "6" }, session.model.rows[2])
		normal("kdc.")
		assert.are.same({ "c" }, session.model.rows[1])
		local nodes = #session.history.nodes
		normal(".") -- Cannot delete the last column.
		assert.are.equal(nodes, #session.history.nodes)
		session.undo()
		normal("dxl.")
		assert.are.same({ "", "" }, session.model.rows[1])
		session.undo()
		assert.are.same({ "", "c" }, session.model.rows[1])
	end)

	it("keeps the last successful deletion across yanks and protected deletions", function()
		session = tbl.edit()
		normal("jddyydd") -- The remaining header can be yanked, but not deleted.
		session.paste(false)
		normal(".")
		assert.are.equal(1, #session.model.rows)
	end)

	it("yanks and pastes multiple Visual-line rows in order", function()
		new_md_buf({ "| h |", "| - |", "| a |", "| b |", "| c |" })
		session = tbl.edit()
		normal("jVjy")
		assert.are.equal("rows", session.register.kind)
		assert.are.same({ { "a" }, { "b" } }, session.register.value)
		assert.are.equal(4, #session.model.rows)
		normal("p")
		assert.are.same({ { "h" }, { "a" }, { "a" }, { "b" }, { "b" }, { "c" } },
			session.model.rows)
		assert.are.equal(2, #session.history.nodes) -- Paste is a single operation.
		session.undo()
		normal("P")
		assert.are.same({ { "h" }, { "a" }, { "b" }, { "a" }, { "b" }, { "c" } },
			session.model.rows)
	end)

	it("deletes Visual-line row ranges as one operation and repeats their size", function()
		new_md_buf({ "| h |", "| - |", "| a |", "| b |", "| c |", "| d |", "| e |" })
		session = tbl.edit()
		normal("jjVkd") -- Backward selection of the first two body rows.
		assert.are.same({ { "h" }, { "c" }, { "d" }, { "e" } }, session.model.rows)
		assert.are.same({ { "a" }, { "b" } }, session.register.value)
		assert.are.equal(2, #session.history.nodes)
		normal(".")
		assert.are.same({ { "h" }, { "e" } }, session.model.rows)
		session.undo()
		assert.are.same({ { "h" }, { "c" }, { "d" }, { "e" } }, session.model.rows)
	end)

	it("skips the separator and protects the header in Visual-line operations", function()
		new_md_buf({ "| h |", "| - |", "| a |", "| b |" })
		session = tbl.edit()
		normal("Vjjx") -- Header, separator, first body row.
		assert.are.same({ { "h" }, { "b" } }, session.model.rows)
		assert.are.same({ "a" }, session.register.value)
		normal("kVy")
		assert.are.same({ "h" }, session.register.value)
		normal("Vd")
		assert.are.same({ { "h" }, { "b" } }, session.model.rows)
		api.nvim_win_set_cursor(session.win, { 2, 0 })
		normal("Vy") -- Separator-only selection has no rows to copy.
		assert.are.same({ "h" }, session.register.value)
	end)

	it("preserves native characterwise Visual yanking in content mode", function()
		session = tbl.edit()
		session.toggle_mode()
		normal("0vly")
		assert.are.equal("| ", vim.fn.getreg('"'))
		assert.is_nil(session.register)
		assert_buf_eq(session.buf, formatted)
	end)

	it("uses w/e/b for cell navigation only in the default mode", function()
		session = tbl.edit()
		normal("web")
		assert.are.same({ 1, 2 }, { session.row, session.col })
		normal("w")
		assert.are.same({ 2, 1 }, { session.row, session.col })
		session.toggle_mode()
		for _, key in ipairs({ "w", "e", "b" }) do
			assert.are.equal("", vim.fn.maparg(key, "n"))
		end
		session.toggle_mode()
		normal("b")
		assert.are.same({ 1, 2 }, { session.row, session.col })
	end)

	it("uses the requested table and cell float titles", function()
		local function title(win)
			return vim.trim(api.nvim_win_get_config(win).title[1][1])
		end
		session = tbl.edit()
		assert.are.equal("Edit Table", title(session.win))
		session.toggle_mode()
		assert.are.equal("Edit Table (content)", title(session.win))
		session.insert_row(false)
		assert.are.equal("Edit Table (content)", title(session.win))
		session.toggle_mode()
		assert.are.equal("Edit Table", title(session.win))
		session.edit_cell()
		assert.are.equal("Edit Cell", title(session.cell_win))
	end)

	it("doubles the default cell width and grows up to ten centered lines", function()
		session = tbl.edit()
		session.edit_cell()
		local function assert_size(height)
			assert.is_true(vim.wait(200, function()
				return api.nvim_win_get_height(session.cell_win) == height
			end))
			local config = api.nvim_win_get_config(session.cell_win)
			local top = (vim.o.showtabline == 2) and 1 or 0
			local bottom = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus > 0 and 1 or 0)
			assert.are.equal(top + math.floor((bottom - top - height - 2) / 2), config.row)
			assert.are.equal(math.floor((vim.o.columns - config.width - 2) / 2), config.col)
		end
		assert.are.equal(math.min(64, vim.o.columns - 6), api.nvim_win_get_width(session.cell_win))
		assert_size(1)
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "one", "two", "three" })
		assert_size(3)
		local lines = {}
		for i = 1, 12 do lines[i] = tostring(i) end
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, lines)
		assert_size(10)
		api.nvim_exec_autocmds("VimResized", {})
		assert_size(10)
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "one" })
		assert_size(1)
	end)

	it("sizes preexisting multiline cells and ignores queued resizes after closure", function()
		new_md_buf({ "| one<br>two |", "| - |" })
		session = tbl.edit()
		session.edit_cell()
		assert.are.equal(2, api.nvim_win_get_height(session.cell_win))
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "one", "two", "three" })
		session.finish_cell()
		session.undo()
		session.edit_cell()
		vim.wait(20)
		assert.are.equal(2, api.nvim_win_get_height(session.cell_win))
	end)

	it("accepts external cell closure as one undoable staged edit", function()
		local source = api.nvim_get_current_buf()
		session = tbl.edit()
		session.edit_cell()
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "external", "edit|pipe" })
		local cell = session.cell_buf
		api.nvim_win_close(session.cell_win, true)
		vim.wait(20)
		assert.is_nil(session.cell_buf)
		assert.is_false(api.nvim_buf_is_valid(cell))
		assert.are.equal("external<br>edit\\|pipe", session.model.rows[1][1])
		assert.are.equal(2, #session.history.nodes)
		assert_buf_eq(source, basic)
		session.undo()
		assert.are.equal("a", session.model.rows[1][1])
	end)

	it("accepts Escape in Normal mode and saves externally dismissed source cells", function()
		local source = api.nvim_get_current_buf()
		session = tbl.edit()
		session.edit_cell()
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "normal Escape" })
		vim.fn.maparg("<Esc>", "n", false, true).callback()
		assert.are.equal("normal Escape", session.model.rows[1][1])
		session.close() -- Discarding the whole transaction is still explicit.
		assert_buf_eq(source, basic)
		session = tbl.action("edit_cell")
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "source dismissal" })
		api.nvim_win_close(session.cell_win, true)
		assert.is_true(vim.wait(200, function() return session.closed == true end))
		assert.are.equal("source dismissal", tbl.tables(source)[1].rows[1][1])
	end)

	it("keeps externally dismissed source cells recoverable after a conflict", function()
		local source = api.nvim_get_current_buf()
		session = tbl.action("edit_cell")
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "recover dismissal" })
		api.nvim_buf_set_lines(source, 0, 1, false, { "conflict" })
		api.nvim_win_close(session.cell_win, true)
		assert.is_true(vim.wait(200, function() return session.headless == false end))
		assert.are.equal("recover dismissal", session.model.rows[1][1])
		assert.is_true(api.nvim_win_is_valid(session.win))
	end)

	it("accepts the original cell even if the preview cursor moves", function()
		session = tbl.edit()
		session.edit_cell()
		api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "original" })
		api.nvim_win_set_cursor(session.win, { 3, session.positions[2][2] })
		session.finish_cell()
		assert.are.equal("original", session.model.rows[1][1])
		assert.are.equal("d", session.model.rows[2][2])
	end)

	it("saves the formatted table and closes with Ctrl-y", function()
		local source = api.nvim_get_current_buf()
		session = tbl.edit()
		session.insert_row(false)
		normal("<C-y>")
		assert.is_true(session.closed)
		assert_buf_eq(source, { "| a   | b   |", "| --- | --- |", "|     |     |", "| c   | d   |" })
	end)

	it("titles, aligns, widens and highlights keymap help without a heading line", function()
		session = tbl.edit()
		for _, mode in ipairs({ "cell", "content" }) do
			if mode == "content" then session.toggle_mode() end
			session.help()
			local config = api.nvim_win_get_config(session.help_win)
			assert.are.equal("Table Editor Keymaps (" .. mode .. " navigation)",
				vim.trim(config.title[1][1]))
			local lines = api.nvim_buf_get_lines(session.help_buf, 0, -1, false)
			assert.is_not_nil(lines[1]:match("^n  "))
			assert.are.equal("?/q/Esc: close", lines[#lines])
			local width = 32
			for _, line in ipairs(lines) do
				width = math.max(width, vim.fn.strdisplaywidth(line))
			end
			assert.are.equal(math.ceil(width * 1.5), session.help_width)
			assert.are.equal(math.min(session.help_width, vim.o.columns - 6), config.width)
			if mode == "cell" then
				local columns = {}
				for _, line in ipairs(lines) do
					if line:match("^n  <Right>") or line:match("^n  h ") then
						table.insert(columns, (line:find("Cell ", 1, true)))
					end
				end
				assert.are.same({ 16, 16 }, columns)
			end
			local marks = api.nvim_buf_get_extmarks(session.help_buf, session.ns, 0, -1,
				{ details = true })
			assert.are.equal(#lines - 1, #marks) -- Every mapping and the footer keys.
			for _, mark in ipairs(marks) do
				assert.are.equal("MarkdownTableKey", mark[4].hl_group)
			end
			vim.fn.maparg("?", "n", false, true).callback()
		end
	end)

	it("confirms cell edits with Enter and Ctrl-y in Normal and Insert mode", function()
		session = tbl.edit()
		for _, mode in ipairs({ "n", "i" }) do
			for _, key in ipairs({ "<CR>", "<C-y>" }) do
				session.edit_cell()
				api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { mode .. key })
				vim.fn.maparg(key, mode, false, true).callback()
				assert.is_nil(session.cell_buf)
				assert.are.equal(mode .. key, session.model.rows[1][1])
			end
		end
	end)

	it("inserts cell newlines with Shift-Enter and Ctrl-j without confirming", function()
		session = tbl.edit()
		for _, key in ipairs({ "<S-CR>", "<C-j>" }) do
			session.edit_cell()
			vim.cmd("stopinsert")
			api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "" })
			local keys = api.nvim_replace_termcodes("ifirst" .. key .. "second<CR>", true, false, true)
			api.nvim_feedkeys(keys, "xt", false)
			assert.is_nil(session.cell_buf)
			assert.are.equal("first<br>second", session.model.rows[1][1])
			session.edit_cell()
			vim.cmd("stopinsert")
			api.nvim_buf_set_lines(session.cell_buf, 0, -1, false, { "ab" })
			api.nvim_win_set_cursor(session.cell_win, { 1, 0 })
			api.nvim_feedkeys(api.nvim_replace_termcodes(key, true, false, true), "xt", false)
			assert.is_not_nil(session.cell_buf)
			assert_buf_eq(session.cell_buf, { "a", "b" })
			normal("<C-y>")
			assert.are.equal("a<br>b", session.model.rows[1][1])
		end
	end)

	it("uses the separator's own column positions for direct-buffer actions", function()
		new_md_buf({ "a|b", "-------|---", "x|y" })
		api.nvim_win_set_cursor(0, { 2, 4 })
		local _, row, col = tbl.context()
		assert.are.same({ 1, 1 }, { row, col })
		tbl.action("yank_cell")
		assert.are.equal("a", vim.fn.getreg('"'))
		api.nvim_win_set_cursor(0, { 2, 9 })
		_, row, col = tbl.context()
		assert.are.same({ 1, 2 }, { row, col })
		session = tbl.edit()
		assert.are.same({ 1, 2 }, { session.row, session.col })
	end)

	it("navigates physically present cells in ragged source tables without modifying them", function()
		local source = new_md_buf({ "| a | b | c |", "| - | - | - |", "| x |", "| p | q |" })
		local tick = api.nvim_buf_get_changedtick(source)
		api.nvim_win_set_cursor(0, { 1, 9 })
		for _, step in ipairs({
			{ "next", 2, 1 }, { "next", 3, 1 }, { "right", 3, 2 },
			{ "next", 1, 1 }, { "previous", 3, 2 }, { "up", 2, 1 },
			{ "down", 3, 1 }, { "left", 3, 1 },
		}) do
			tbl.action(step[1])
			local _, row, col = tbl.context()
			assert.are.same({ step[2], step[3] }, { row, col })
		end
		assert.are.equal(tick, api.nvim_buf_get_changedtick(source))
	end)

	it("leaves untouched cell Markdown spelling and operation history intact", function()
		new_md_buf({ "| one<BR />two |", "| - |" })
		session = tbl.edit()
		session.edit_cell()
		assert_buf_eq(session.cell_buf, { "one", "two" })
		session.finish_cell()
		assert.are.equal("one<BR />two", session.model.rows[1][1])
		assert.are.equal(1, #session.history.nodes)
	end)

	it("does not format the source or conflict when an untouched cell is dismissed", function()
		local source = new_md_buf({ "a|b<BR/>c", "-| -", "x|y" })
		local tick = api.nvim_buf_get_changedtick(source)
		session = tbl.action("edit_cell")
		session.finish_cell()
		assert.is_true(session.closed)
		assert.are.equal(tick, api.nvim_buf_get_changedtick(source))
		session = tbl.action("edit_cell")
		api.nvim_buf_set_lines(source, 2, 3, false, { "changed|elsewhere" })
		session.finish_cell()
		assert.is_true(session.closed)
		assert_buf_eq(source, { "a|b<BR/>c", "-| -", "changed|elsewhere" })
	end)

	it("inserts source rows and columns as single undoable edits", function()
		for _, action in ipairs({ "row_above", "row_below", "column_before", "column_after" }) do
			local source = new_md_buf(basic)
			api.nvim_win_set_cursor(0, { 3, 6 })
			vim.cmd("let &undolevels = &undolevels")
			session = tbl.action(action)
			assert.is_true(session.closed)
			assert.are.equal(source, api.nvim_get_current_buf())
			local model, row, col = tbl.context()
			if action:match("^row_") then
				assert.are.equal(3, #model.rows)
				assert.are.same({ "", "" }, model.rows[row])
			else
				assert.are.equal(3, #model.align)
				assert.are.equal("", model.rows[row][col])
			end
			vim.cmd("undo")
			assert_buf_eq(source, basic)
		end
	end)

	it("aligns the targeted source column from differently sized separator cells", function()
		for _, align in ipairs({ "left", "center", "right", "none" }) do
			local source = new_md_buf({ "> a|b", "> -------|---", "> x|y" })
			api.nvim_win_set_cursor(0, { 2, 6 })
			session = tbl.action("align_" .. align)
			assert.is_true(session.closed)
			assert.are.same({ align, "none" }, tbl.tables(source)[1].align)
		end
	end)

	it("keeps source metadata outside operation-history snapshots", function()
		session = tbl.edit()
		local first, starts = session.model.first, session.model.starts
		session.insert_row(false)
		session.undo()
		assert.are.equal(first, session.model.first)
		assert.are.equal(starts, session.model.starts)
		assert.is_nil(session.history.nodes[1].state.data.first)
		assert.is_nil(session.history.nodes[1].state.data.starts)
	end)

	it("renders long Unicode cells with tabs without changing display alignment", function()
		local text = string.rep("界", 1000) .. "\tend"
		local source = new_md_buf({ "| h |", "| - |", "| " .. text .. " |" })
		vim.bo[source].tabstop = 4
		tbl.format(0, -1)
		local lines = api.nvim_buf_get_lines(source, 0, -1, false)
		assert.are.equal(vim.fn.strwidth(lines[1]), vim.fn.strwidth(lines[3]))
		assert.is_not_nil(lines[3]:find(string.rep("界", 1000) .. "    end", 1, true))
	end)

	it("retains body rows when the parser errors on a trailing empty row", function()
		for _, prefix in ipairs({ "", "> " }) do
			local lines = {}
			for _, line in ipairs({ "| a | b |", "| --- | --- |", "| c | d |", "| | |" }) do
				table.insert(lines, prefix .. line)
			end
			local source = new_md_buf(lines)
			local model = tbl.tables(source)[1]
			assert.are.same({ { "a", "b" }, { "c", "d" }, { "", "" } }, model.rows)
			api.nvim_win_set_cursor(0, { 4, #prefix + 1 })
			session = tbl.edit()
			assert.are.equal(3, session.row)
			session.close()
		end
	end)

	it("does not recover across blank lines or into fenced table-like text", function()
		local source = new_md_buf({
			"| a | b |", "| --- | --- |", "| c | d |", "| | |", "", "```",
			"| not | data |", "| --- | --- |", "| | |", "```",
		})
		local models = tbl.tables(source)
		assert.are.equal(1, #models)
		assert.are.equal(4, models[1].last)
		assert.are.equal(3, #models[1].rows)
	end)

	it("ignores soft-wrap display options when measuring Markdown columns", function()
		local source = new_md_buf({ "| h |", "| --- |", "| " .. string.rep("界", 100) .. " |" })
		local showbreak, list = vim.wo.showbreak, vim.wo.list
		vim.wo.showbreak, vim.wo.list = ">>> ", true
		tbl.format(0, -1)
		local lines = api.nvim_buf_get_lines(source, 0, -1, false)
		vim.wo.showbreak, vim.wo.list = showbreak, list
		assert.are.equal(vim.fn.strwidth(lines[1]), vim.fn.strwidth(lines[3]))
		local tick = api.nvim_buf_get_changedtick(source)
		tbl.format(0, -1)
		assert.are.equal(tick, api.nvim_buf_get_changedtick(source))
	end)

	it("registers usable buffer-local navigation and editing maps", function()
		session = tbl.edit()
		local function press(key)
			local mapping = vim.fn.maparg(key, "n", false, true)
			assert.are.equal(1, mapping.buffer)
			mapping.callback()
		end
		press("l")
		press("j")
		assert.are.same({ 2, 2 }, { session.row, session.col })
		press("<CR>")
		assert.are.equal(session.cell_buf, api.nvim_get_current_buf())
		press("<Esc>")
		assert.are.equal(session.buf, api.nvim_get_current_buf())
		press("q")
		assert.is_true(session.closed)
	end)
end)
