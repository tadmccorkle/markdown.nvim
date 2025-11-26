local api = vim.api

local toc = require("markdown.toc")

local function new_md_buf()
	local bufnr = api.nvim_create_buf(true, true)
	api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
	api.nvim_set_option_value("expandtab", true, { buf = bufnr })
	api.nvim_set_option_value("tabstop", 2, { buf = bufnr })
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

	it("inserts at row position", function()
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
		toc.insert_toc({ markers = { "-" }, start_row = 3 })
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

	it("replaces line range", function()
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
		toc.insert_toc({ markers = { "-" }, start_row = 2, end_row = 3 })
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
		toc.insert_toc({ markers = { "-" }, start_row = 0 })
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
		toc.insert_toc({ markers = { "-" }, start_row = 0 })
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
		toc.insert_toc({ markers = { "-" }, start_row = 0 })
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

	it("omits flagged headings", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"# h1 will be omitted <!-- toc omit heading -->",
			"## h1.2",
			"<!-- toc omit heading -->",
			"#### h1.3 will be omitted",
			"### h1.3.1",
			"#### <!-- toc omit heading --> h1.3.1.1 will be omitted",
			"## h1.4",
			"<!-- toc omit heading -->",
			"omitted setext",
			"===",
			"another omitted setext <!-- toc omit heading -->",
			"---",
			"setext",
			"==="
		})
		toc.insert_toc({ markers = { "-" }, start_row = 1 })
		assert_buf_eq(bufnr, {
			"# h1 will be omitted <!-- toc omit heading -->",
			"- [h1.2](#h12)",
			"  - [h1.3.1](#h131)",
			"- [h1.4](#h14)",
			"- [setext](#setext)",
			"## h1.2",
			"<!-- toc omit heading -->",
			"#### h1.3 will be omitted",
			"### h1.3.1",
			"#### <!-- toc omit heading --> h1.3.1.1 will be omitted",
			"## h1.4",
			"<!-- toc omit heading -->",
			"omitted setext",
			"===",
			"another omitted setext <!-- toc omit heading -->",
			"---",
			"setext",
			"==="
		})
	end)

	it("omits flagged sections", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"# h1",
			"<!-- toc omit section -->",
			"## h1.1 section will be omitted",
			"### in section",
			"##### also in section",
			"## h1.2",
			"### h1.2.1 <!-- toc omit section -->",
			"#### in section, too",
			"<!-- toc omit section -->",
			"setext section omitted",
			"===",
			"setext in section",
			"---",
			"setext",
			"==="
		})
		toc.insert_toc({ markers = { "-" }, start_row = 1 })
		assert_buf_eq(bufnr, {
			"# h1",
			"- [h1](#h1)",
			"  - [h1.2](#h12)",
			"- [setext](#setext)",
			"<!-- toc omit section -->",
			"## h1.1 section will be omitted",
			"### in section",
			"##### also in section",
			"## h1.2",
			"### h1.2.1 <!-- toc omit section -->",
			"#### in section, too",
			"<!-- toc omit section -->",
			"setext section omitted",
			"===",
			"setext in section",
			"---",
			"setext",
			"==="
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
		toc.insert_toc({ markers = { "-" }, start_row = 0 })
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
		toc.insert_toc({ markers = { "-" }, start_row = 0 })
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
		toc.insert_toc({ markers = { "-" }, start_row = 0 })
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
		toc.insert_toc({ markers = { "-" }, start_row = 0 })
		assert_buf_eq(bufnr, {
			"- [h1  content](#h1--content)",
			"",
			"# h1 <!-- comment --> c<!--comment-->ontent",
		})
	end)

	it("can omit headings by level", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"",
			"# h1",
			"### h2",
			"## h3",
			"### h4",
		})
		toc.insert_toc({ markers = { "-" }, start_row = 0, max_level = 2 })
		assert_buf_eq(bufnr, {
			"- [h1](#h1)",
			"  - [h3](#h3)",
			"",
			"# h1",
			"### h2",
			"## h3",
			"### h4",
		})
	end)

	it("supports alternating markers", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"",
			"# h1",
			"### h2",
			"## h3",
			"### h4",
		})
		toc.insert_toc({ markers = { "*", "+" }, start_row = 0 })
		assert_buf_eq(bufnr, {
			"* [h1](#h1)",
			"  + [h2](#h2)",
			"  + [h3](#h3)",
			"    * [h4](#h4)",
			"",
			"# h1",
			"### h2",
			"## h3",
			"### h4",
		})
	end)

	it("supports ordered markers", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"",
			"# h1",
			"### h2",
			"## h3",
			"### h4",
		})
		toc.insert_toc({ markers = { ".", ")" }, start_row = 0 })
		assert_buf_eq(bufnr, {
			"1. [h1](#h1)",
			"   1) [h2](#h2)",
			"   2) [h3](#h3)",
			"      1. [h4](#h4)",
			"",
			"# h1",
			"### h2",
			"## h3",
			"### h4",
		})
	end)

	it("can show headings in loclist", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"# h1",
			"## h2 <!-- toc omit section -->",
			"### h3",
			"## h4",
			"### h5 <!-- toc omit heading -->",
		})
		toc.set_loclist_toc({ omit_flagged = true })
		assert_buf_eq(0, {
			"h1",
			"  h4"
		})
	end)

	it("can show headings with max level in loclist", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"# h1",
			"## h2",
			"### h3",
		})
		toc.set_loclist_toc({ max_level = 2 })
		assert_buf_eq(0, {
			"h1",
			"  h2",
		})
	end)

	it("can show all headings in loclist", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"# h1",
			"## h2 <!-- toc omit section -->",
			"### h3",
			"## h4",
			"### h5 <!-- toc omit heading -->",
		})
		toc.set_loclist_toc({ omit_flagged = false })
		assert_buf_eq(0, {
			"h1",
			"  h2",
			"    h3",
			"  h4",
			"    h5",
		})
	end)
end)
