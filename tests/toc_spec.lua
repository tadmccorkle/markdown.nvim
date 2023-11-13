local api = vim.api

local toc = require("markdown.toc")

local function new_md_buf()
	local bufnr = api.nvim_create_buf(true, true)
	api.nvim_buf_set_option(bufnr, "filetype", "markdown")
	api.nvim_buf_set_option(bufnr, "expandtab", true)
	api.nvim_buf_set_option(bufnr, "tabstop", 2)
	api.nvim_win_set_buf(0, bufnr)
	return bufnr
end

local function set_buf(bufnr, lines)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

local function assert_buf_eq(bufnr, lines)
	assert.are.same(lines, api.nvim_buf_get_lines(bufnr, 0, -1, false))
end

describe("toc", function()
	require("markdown").setup()

	it("inserts in normal mode", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"# h1",
			"",
			"table of contents",
			"will be placed here",
			"",
			"## h1.2",
			"## h1.3",
			"### h1.3.1",
			"#### h1.3.1.1",
			"## h1.4",
		})

		api.nvim_win_set_cursor(0, { 4, 0 })
		toc.insert_toc({ range = 0 })
		assert_buf_eq(bufnr, {
			"# h1",
			"",
			"table of contents",
			"- [h1](#h1)",
			"  - [h1.2](#h12)",
			"  - [h1.3](#h13)",
			"    - [h1.3.1](#h131)",
			"      - [h1.3.1.1](#h1311)",
			"  - [h1.4](#h14)",
			"will be placed here",
			"",
			"## h1.2",
			"## h1.3",
			"### h1.3.1",
			"#### h1.3.1.1",
			"## h1.4",
		})
	end)

	it("replaces lines in visual mode", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"# h1",
			"",
			"table of contents",
			"will be placed here",
			"",
			"## h1.2",
			"## h1.3",
			"### h1.3.1",
			"#### h1.3.1.1",
			"## h1.4",
		})
		toc.insert_toc({ range = 2, line1 = 3, line2 = 4 })
		assert_buf_eq(bufnr, {
			"# h1",
			"",
			"- [h1](#h1)",
			"  - [h1.2](#h12)",
			"  - [h1.3](#h13)",
			"    - [h1.3.1](#h131)",
			"      - [h1.3.1.1](#h1311)",
			"  - [h1.4](#h14)",
			"",
			"## h1.2",
			"## h1.3",
			"### h1.3.1",
			"#### h1.3.1.1",
			"## h1.4",
		})
	end)

	it("handles missing levels", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"",
			"## h1.2",
			"#### h1.3",
			"### h1.3.1",
			"#### h1.3.1.1",
			"## h1.4",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		toc.insert_toc({ range = 0 })
		assert_buf_eq(bufnr, {
			"- [h1.2](#h12)",
			"  - [h1.3](#h13)",
			"  - [h1.3.1](#h131)",
			"    - [h1.3.1.1](#h1311)",
			"- [h1.4](#h14)",
			"",
			"## h1.2",
			"#### h1.3",
			"### h1.3.1",
			"#### h1.3.1.1",
			"## h1.4",
		})
	end)

	it("supports setext headings", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"",
			"h1",
			"===",
			"h2",
			"---",
			"h3",
			"---",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		toc.insert_toc({ range = 0 })
		assert_buf_eq(bufnr, {
			"- [h1](#h1)",
			"  - [h2](#h2)",
			"  - [h3](#h3)",
			"",
			"h1",
			"===",
			"h2",
			"---",
			"h3",
			"---",
		})
	end)

	it("supports mixed atx and setext headings", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"",
			"# atx1",
			"setext1",
			"===",
			"setext2",
			"---",
			"### atx2",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		toc.insert_toc({ range = 0 })
		assert_buf_eq(bufnr, {
			"- [atx1](#atx1)",
			"- [setext1](#setext1)",
			"  - [setext2](#setext2)",
			"    - [atx2](#atx2)",
			"",
			"# atx1",
			"setext1",
			"===",
			"setext2",
			"---",
			"### atx2",
		})
	end)

	it("omits flagged sections", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"# h1 will be omitted <!-- omit in toc -->",
			"## h1.2",
			"<!-- omit in toc -->",
			"#### h1.3 will be omitted",
			"### h1.3.1",
			"#### <!-- omit in toc --> h1.3.1.1 will be omitted",
			"## h1.4",
			"<!-- omit in toc -->",
			"omitted setext",
			"===",
			"another omitted setext <!-- omit in toc -->",
			"---",
			"setext",
			"==="
		})
		api.nvim_win_set_cursor(0, { 2, 0 })
		toc.insert_toc({ range = 0 })
		assert_buf_eq(bufnr, {
			"# h1 will be omitted <!-- omit in toc -->",
			"- [h1.2](#h12)",
			"  - [h1.3.1](#h131)",
			"- [h1.4](#h14)",
			"- [setext](#setext)",
			"## h1.2",
			"<!-- omit in toc -->",
			"#### h1.3 will be omitted",
			"### h1.3.1",
			"#### <!-- omit in toc --> h1.3.1.1 will be omitted",
			"## h1.4",
			"<!-- omit in toc -->",
			"omitted setext",
			"===",
			"another omitted setext <!-- omit in toc -->",
			"---",
			"setext",
			"==="
		})
	end)

	it("abides by tabstop", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"",
			"# h1",
			"## h2",
			"### h3",
			"## h4",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		api.nvim_buf_set_option(0, "tabstop", 3)
		toc.insert_toc({ range = 0 })
		assert_buf_eq(bufnr, {
			"- [h1](#h1)",
			"   - [h2](#h2)",
			"      - [h3](#h3)",
			"   - [h4](#h4)",
			"",
			"# h1",
			"## h2",
			"### h3",
			"## h4",
		})
	end)

	it("abides by expandtab", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"",
			"# h1",
			"## h2",
			"### h3",
			"## h4",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		api.nvim_buf_set_option(0, "expandtab", false)
		toc.insert_toc({ range = 0 })
		assert_buf_eq(bufnr, {
			"- [h1](#h1)",
			"	- [h2](#h2)",
			"		- [h3](#h3)",
			"	- [h4](#h4)",
			"",
			"# h1",
			"## h2",
			"### h3",
			"## h4",
		})
	end)

	it("ignores sections within containers", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"",
			"# h1",
			"> ## heading in a quote",
			"> this won't be included in toc",
			"## h2",
			"- ### heading in a list",
			"- it won't be included either",
			"### h3",
			"## h4",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		toc.insert_toc({ range = 0 })
		assert_buf_eq(bufnr, {
			"- [h1](#h1)",
			"  - [h2](#h2)",
			"    - [h3](#h3)",
			"  - [h4](#h4)",
			"",
			"# h1",
			"> ## heading in a quote",
			"> this won't be included in toc",
			"## h2",
			"- ### heading in a list",
			"- it won't be included either",
			"### h3",
			"## h4",
		})
	end)

	it("removes inline styles from link destination", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"",
			"# _h1 this __is__ styled_",
			"## *h2* `code`",
			"### _h3 is_styled_ too_",
			"## h4 word_word_",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		toc.insert_toc({ range = 0 })
		assert_buf_eq(bufnr, {
			"- [_h1 this __is__ styled_](#h1-this-is-styled)",
			"  - [*h2* `code`](#h2-code)",
			"    - [_h3 is_styled_ too_](#h3-is_styled-too_)",
			"  - [h4 word_word_](#h4-word_word_)",
			"",
			"# _h1 this __is__ styled_",
			"## *h2* `code`",
			"### _h3 is_styled_ too_",
			"## h4 word_word_",
		})
	end)

	it("santizes and slugifies destination", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"",
			"# h1~`!@#$%^&*()-_+={[]}|\\:;\"'<,>.?/ content",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		toc.insert_toc({ range = 0 })
		assert_buf_eq(bufnr, {
			"- [h1~`!@#$%^&*()-_+={[]}|\\:;\"'<,>.?/ content](#h1-_-content)",
			"",
			"# h1~`!@#$%^&*()-_+={[]}|\\:;\"'<,>.?/ content",
		})
	end)

	it("santizes text", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"",
			"# h1 <!-- comment --> c<!--comment-->ontent",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		toc.insert_toc({ range = 0 })
		assert_buf_eq(bufnr, {
			"- [h1  content](#h1--content)",
			"",
			"# h1 <!-- comment --> c<!--comment-->ontent",
		})
	end)
end)
