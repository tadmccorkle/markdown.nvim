local api = vim.api

local function new_md_buf()
	local bufnr = api.nvim_create_buf(true, true)
	api.nvim_buf_set_option(bufnr, "filetype", "markdown")
	api.nvim_win_set_buf(0, bufnr)
	return bufnr
end

local function set_buf(bufnr, lines)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

local function assert_buf_eq(bufnr, lines)
	assert.are.same(lines, api.nvim_buf_get_lines(bufnr, 0, -1, false))
end

describe("list", function()
	require("markdown").setup()

	local list = require("markdown.list")

	local function insert_li_above(pos, text)
		api.nvim_win_set_cursor(0, pos)
		list.insert_list_item_above()
		vim.cmd("normal a" .. text)
	end

	local function insert_li_below(pos, text)
		api.nvim_win_set_cursor(0, pos)
		list.insert_list_item_below()
		vim.cmd("normal a" .. text)
	end

	it("resets list numbering in buffer", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"- l1",
			"  1. a",
			"  1. b",
			"  3. c",
			"  5. d",
			"  2. e",
			"- l2",
			"  1) aa",
			"     1. aaa",
			"     1. bbb",
			"  55) bb",
		})
		list.reset_list_numbering(0, -1)
		assert_buf_eq(bufnr, {
			"- l1",
			"  1. a",
			"  2. b",
			"  3. c",
			"  4. d",
			"  5. e",
			"- l2",
			"  1) aa",
			"     1. aaa",
			"     2. bbb",
			"  2) bb",
		})
	end)

	it("resets list numbering in range", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"- l1",
			"  1. a",
			"  1. b",
			"  3. c",
			"  5. d",
			"  2. e",
			"- l2",
			"  1) aa",
			"     1. aaa",
			"     1. bbb",
			"  55) bb",
		})
		list.reset_list_numbering(1, 5)
		assert_buf_eq(bufnr, {
			"- l1",
			"  1. a",
			"  2. b",
			"  3. c",
			"  4. d",
			"  5. e",
			"- l2",
			"  1) aa",
			"     1. aaa",
			"     1. bbb",
			"  55) bb",
		})
	end)

	it("inserts list items", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"- l1",
			"  * a",
			"- l4",
			"",
			"  l4 continued",
			"  + aa",
			"- l7",
		})
		insert_li_above({ 1, 0 }, "l2")
		insert_li_below({ 2, 0 }, "l3")
		insert_li_above({ 4, 0 }, "b")
		insert_li_below({ 5, 0 }, "c")
		insert_li_above({ 8, 0 }, "l5")
		insert_li_below({ 10, 5 }, "l6")
		insert_li_above({ 12, 5 }, "bb")
		insert_li_below({ 13, 5 }, "cc")
		insert_li_above({ 15, 0 }, "l8")
		insert_li_below({ 16, 0 }, "l9")
		assert_buf_eq(bufnr, {
			"- l2",
			"- l1",
			"- l3",
			"  * b",
			"  * a",
			"  * c",
			"- l5",
			"- l4",
			"",
			"  l4 continued",
			"- l6",
			"  + bb",
			"  + aa",
			"  + cc",
			"- l8",
			"- l7",
			"- l9",
		})
	end)

	it("renumbers current list when inserting list item", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"- l1",
			"  1. a",
			"  1. b",
			"- l2",
			"  1) aa",
			"     1. aaa",
			"     1. bbb",
			"  55) bb",
		})
		insert_li_above({ 3, 0 }, "c")
		assert_buf_eq(bufnr, {
			"- l1",
			"  1. a",
			"  2. c",
			"  3. b",
			"- l2",
			"  1) aa",
			"     1. aaa",
			"     1. bbb",
			"  55) bb",
		})
		insert_li_below({ 3, 0 }, "d")
		assert_buf_eq(bufnr, {
			"- l1",
			"  1. a",
			"  2. c",
			"  3. d",
			"  4. b",
			"- l2",
			"  1) aa",
			"     1. aaa",
			"     1. bbb",
			"  55) bb",
		})
	end)

	it("correctly indents ordered lists", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"1. x",
			"2. x",
			"3. x",
			"4. x",
			"5. x",
			"6. x",
			"7. x",
			"8. x",
			"   - x",
			"9. x",
			"   - x",
			"10. x",
			"    - x",
			"11. x",
		})
		insert_li_above({ 1, 0 }, "y")
		assert_buf_eq(bufnr, {
			"1. y",
			"2. x",
			"3. x",
			"4. x",
			"5. x",
			"6. x",
			"7. x",
			"8. x",
			"9. x",
			"   - x",
			"10. x",
			"    - x",
			"11. x",
			"    - x",
			"12. x",
		})
	end)

	it("maintains indentation when inserting list item", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"- l1",
			"   * a",
			"- l2",
			"	+ aa",
			"- aa",
		})
		insert_li_below({ 2, 0 }, "test")
		insert_li_above({ 5, 3 }, "test")
		assert_buf_eq(bufnr, {
			"- l1",
			"   * a",
			"   * test",
			"- l2",
			"	+ test",
			"	+ aa",
			"- aa",
		})
	end)

	it("continues task lists when inserting list item", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, { "- [x] l1" })
		insert_li_above({ 1, 0 }, "test1")
		insert_li_below({ 1, 0 }, "test2")
		insert_li_below({ 3, 0 }, "test3")
		insert_li_above({ 4, 0 }, "test4")
		assert_buf_eq(bufnr, {
			"- [ ] test1",
			"- [ ] test2",
			"- [x] l1",
			"- [ ] test4",
			"- [ ] test3",
		})
	end)

	describe("tasks", function()
		it("toggles tasks", function()
			local bufnr = new_md_buf()
			set_buf(bufnr, {
				"- [ ] task",
				"- [ ] task",
				"- [x] task",
				"- [ ] task",
				"- [ ] task",
			})
			list.toggle_task(1, 1)
			set_buf(bufnr, {
				"- [ ] task",
				"- [x] task",
				"- [x] task",
				"- [ ] task",
				"- [ ] task",
			})
			list.toggle_task(1, 3)
			assert_buf_eq(bufnr, {
				"- [ ] task",
				"- [x] task",
				"- [x] task",
				"- [x] task",
				"- [ ] task",
			})
			list.toggle_task(1, 3)
			assert_buf_eq(bufnr, {
				"- [ ] task",
				"- [ ] task",
				"- [ ] task",
				"- [ ] task",
				"- [ ] task",
			})
			list.toggle_task(0, 4)
			assert_buf_eq(bufnr, {
				"- [x] task",
				"- [x] task",
				"- [x] task",
				"- [x] task",
				"- [x] task",
			})
		end)
	end)
end)
