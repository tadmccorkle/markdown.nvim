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

	it("deduplicates slugs and follows every generated destination", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"# Heading",
			"# Heading",
			"Heading 1",
			"=========",
			"# Heading 1",
			"# Heading-1",
			"# Heading",
			"# 中文 日本語",
			"中文 日本語",
			"-----------",
			"# **HEADING**",
		})
		local entries = {
			"- [Heading](#heading)",
			"- [Heading](#heading-1)",
			"- [Heading 1](#heading-1-1)",
			"- [Heading 1](#heading-1-2)",
			"- [Heading-1](#heading-1-3)",
			"- [Heading](#heading-2)",
			"- [中文 日本語](#中文-日本語)",
			"  - [中文 日本語](#中文-日本語-1)",
			"- [**HEADING**](#heading-3)",
		}
		toc.insert_toc({ markers = { "-" }, start_row = 0 })
		assert.are.same(entries, api.nvim_buf_get_lines(bufnr, 0, #entries, false))
		local heading_lines = { 1, 2, 3, 5, 6, 7, 8, 9, 11 }
		for i, line in ipairs(heading_lines) do
			api.nvim_win_set_cursor(0, { i, 4 })
			require("markdown.link").follow()
			assert.are.same({ #entries + line, 0 }, api.nvim_win_get_cursor(0))
		end
	end)

	it("numbers omitted headings but excludes container headings", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"> # Same",
			"",
			"- # Same",
			"",
			"# Same <!-- toc omit heading -->",
			"# Same <!-- toc omit section -->",
			"## Same",
			"# Same",
			"### Same",
			"# Same",
		})
		toc.insert_toc({ markers = { "-" }, start_row = 0, max_level = 1 })
		assert.are.same({
			"- [Same](#same-3)",
			"- [Same](#same-5)",
		}, api.nvim_buf_get_lines(bufnr, 0, 2, false))
		for i, line in ipairs({ 10, 12 }) do
			api.nvim_win_set_cursor(0, { i, 4 })
			require("markdown.link").follow()
			assert.are.same({ line, 0 }, api.nvim_win_get_cursor(0))
		end
	end)

	it("avoids suffixes already used by natural headings", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, { "# Heading-1", "# Heading", "# Heading", "# Heading-1" })
		toc.insert_toc({ markers = { "-" }, start_row = 0 })
		assert.are.same({
			"- [Heading-1](#heading-1)",
			"- [Heading](#heading)",
			"- [Heading](#heading-2)",
			"- [Heading-1](#heading-1-1)",
		}, api.nvim_buf_get_lines(bufnr, 0, 4, false))
	end)

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

	it("numbers destinations after removing the replacement range", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"# Same",
			"",
			"# Same",
			"# Same 1",
			"# Same",
		})
		toc.insert_toc({ markers = { "-" }, start_row = 0, end_row = 1 })
		assert_buf_eq(bufnr, {
			"- [Same](#same)",
			"- [Same 1](#same-1)",
			"- [Same](#same-2)",
			"# Same",
			"# Same 1",
			"# Same",
		})
		for i = 1, 3 do
			api.nvim_win_set_cursor(0, { i, 4 })
			require("markdown.link").follow()
			assert.are.same({ i + 3, 0 }, api.nvim_win_get_cursor(0))
		end
	end)

	it("reparses headings partially removed by replacement", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, { "Same", "====", "", "# Same", "# Same" })
		toc.insert_toc({ markers = { "-" }, start_row = 1, end_row = 2 })
		assert_buf_eq(bufnr, {
			"Same",
			"- [Same](#same)",
			"- [Same](#same-1)",
			"# Same",
			"# Same",
		})
		for i = 2, 3 do
			api.nvim_win_set_cursor(0, { i, 4 })
			require("markdown.link").follow()
			assert.are.same({ i + 2, 0 }, api.nvim_win_get_cursor(0))
		end
	end)

	it("undoes and redoes replacement as one change", function()
		local bufnr = new_md_buf()
		local original = { "# Same", "", "# Same" }
		set_buf(bufnr, original)
		-- End the setup edit's undo block, as returning to normal mode would.
		vim.cmd("let &g:undolevels = &g:undolevels")
		local sequence = vim.fn.undotree().seq_cur
		toc.insert_toc({ markers = { "-" }, start_row = 0, end_row = 1 })
		local expected = { "- [Same](#same)", "# Same" }
		assert_buf_eq(bufnr, expected)
		assert.are.same(sequence + 1, vim.fn.undotree().seq_cur)
		vim.cmd("undo")
		assert_buf_eq(bufnr, original)
		vim.cmd("redo")
		assert_buf_eq(bufnr, expected)
	end)

	it("restores the selected text if replacement TOC generation fails", function()
		local bufnr = new_md_buf()
		local original = { "# Same", "", "# Same" }
		set_buf(bufnr, original)
		vim.cmd("let &g:undolevels = &g:undolevels")
		local heading = require("markdown.heading")
		local get_headings = heading.get_document_headings
		local intermediate
		heading.get_document_headings = function()
			intermediate = api.nvim_buf_get_lines(bufnr, 0, -1, false)
			error("TOC generation failed", 0)
		end
		local ok, err = pcall(toc.insert_toc, { markers = { "-" }, start_row = 0, end_row = 1 })
		heading.get_document_headings = get_headings
		assert.is_false(ok)
		assert.are.same("TOC generation failed", err)
		assert.are.same({ "", "# Same" }, intermediate)
		assert_buf_eq(bufnr, original)
		vim.cmd("undo")
		assert_buf_eq(bufnr, original)
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
			"===",
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
			"===",
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
			"===",
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
			"===",
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

	it("can set headings in loclist", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"# h1",
			"## h2 <!-- toc omit section -->",
			"### h3",
			"## h4",
			"### h5 <!-- toc omit heading -->",
		})
		toc.set_loclist_toc({ omit_flagged = true })
		vim.cmd("lopen")
		assert_buf_eq(0, {
			"|1| h1",
			"|4| h4",
		})
		vim.cmd("lclose")
	end)

	it("can set headings with max level in loclist", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"# h1",
			"## h2",
			"### h3",
		})
		toc.set_loclist_toc({ max_level = 2 })
		vim.cmd("lopen")
		assert_buf_eq(0, {
			"|1| h1",
			"|2| h2",
		})
		vim.cmd("lclose")
	end)

	it("can set all headings in loclist", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"# h1",
			"## h2 <!-- toc omit section -->",
			"### h3",
			"## h4",
			"### h5 <!-- toc omit heading -->",
		})
		toc.set_loclist_toc({ omit_flagged = false })
		vim.cmd("lopen")
		assert_buf_eq(0, {
			"|1| h1",
			"|2| h2",
			"|3| h3",
			"|4| h4",
			"|5| h5",
		})
		vim.cmd("lclose")
	end)
end)
