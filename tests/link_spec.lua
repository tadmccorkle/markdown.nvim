local api = vim.api

local link = require("markdown.link")

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

describe("link", function()
	vim.cmd("runtime plugin/markdown.lua")
	require("markdown").setup()

	it("can add over motion", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gliw")
		assert_buf_eq(bufnr, { "[test]()" })
		vim.cmd("normal adestination")
		assert_buf_eq(bufnr, { "[test](destination)" })
	end)

	it("can add over visual selection", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal vlgl")
		assert_buf_eq(bufnr, { "t[es]()t" })
		vim.cmd("normal adestination")
		assert_buf_eq(bufnr, { "t[es](destination)t" })
	end)

	it("can follow headings", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"[test](#test)",
			"# Test~`!@#$%^&*(){[|\\<,>.?/]}-2",
			"## Test",
			"[test2](#test-2)"
		})
		api.nvim_win_set_cursor(0, { 1, 1 })
		link.follow()
		assert.are.same({ 3, 0 }, api.nvim_win_get_cursor(0))
		vim.cmd("normal j")
		link.follow()
		assert.are.same({ 2, 0 }, api.nvim_win_get_cursor(0))
	end)

	it("can paste URLs as links", function()
		local bufnr = new_md_buf()

		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal viw")
		api.nvim_paste("https://example.com", true, -1)
		assert_buf_eq(bufnr, { "[test](https://example.com)" })

		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal viw")
		api.nvim_paste("http://example.com", true, -1)
		assert_buf_eq(bufnr, { "[test](http://example.com)" })

		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal viw")
		api.nvim_paste("www.example.com", true, -1)
		assert_buf_eq(bufnr, { "[test](www.example.com)" })
	end)
end)
