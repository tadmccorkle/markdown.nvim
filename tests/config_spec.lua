local api = vim.api

local function new_buf()
	local bufnr = api.nvim_create_buf(true, true)
	api.nvim_win_set_buf(0, bufnr)
	return bufnr
end

local function set_buf(bufnr, lines)
	api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
end

local function assert_buf_eq(bufnr, lines)
	assert.are.same(lines, api.nvim_buf_get_lines(bufnr, 0, -1, false))
end

describe("config", function()
	vim.cmd("runtime plugin/markdown.lua")

	before_each(function()
		require("markdown.config"):reset()
	end)

	it("can change file type", function()
		local bufnr = new_buf()
		set_buf(bufnr, { "coffee" })

		require("markdown").setup({ file_types = "donuts" })
		api.nvim_buf_set_option(bufnr, "filetype", "markdown")
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gsiwi")
		assert_buf_eq(bufnr, { "cwioffee" })

		api.nvim_buf_set_option(bufnr, "filetype", "donuts")
		api.nvim_win_set_cursor(0, { 1, 2 })
		vim.cmd("normal gsiwi")
		assert_buf_eq(bufnr, { "*cwioffee*" })

		require("markdown").setup({ file_types = { "donuts", "jelly" } })
		bufnr = new_buf()
		set_buf(bufnr, { "coffee" })
		api.nvim_buf_set_option(bufnr, "filetype", "jelly")
		api.nvim_win_set_cursor(0, { 1, 3 })
		vim.cmd("normal gsiwi")
		assert_buf_eq(bufnr, { "*coffee*" })
	end)

	it("can change file pattern", function()
		local bufnr = new_buf()
		set_buf(bufnr, { "test" })

		require("markdown").setup({ file_patterns = "*.tst" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gsiwi")
		assert_buf_eq(bufnr, { "twiest" })

		vim.cmd("e test.tst")
		bufnr = api.nvim_win_get_buf(0)
		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gsiwi")
		assert_buf_eq(bufnr, { "*test*" })

		require("markdown").setup({ file_patterns = { "*.tst", "*.sts" } })
		vim.cmd("e test.sts")
		bufnr = api.nvim_win_get_buf(0)
		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gsiwi")
		assert_buf_eq(bufnr, { "*test*" })
	end)

	it("can disable inline surround mappings", function()
		require("markdown").setup({ inline_surround = { mappings = { enable = false } } })

		local bufnr = new_buf()
		set_buf(bufnr, { "test" })
		api.nvim_buf_set_option(bufnr, "filetype", "markdown")
		vim.cmd("normal gsiwi")
		assert_buf_eq(bufnr, { "witest" })
	end)

	it("can change inline mappings", function()
		require("markdown").setup({
			inline_surround = {
				mappings = {
					toggle = "ys",
					toggle_line = "yS",
					delete = "yd",
					change = "yc",
				},
			},
		})

		local bufnr = new_buf()
		set_buf(bufnr, { "test" })
		api.nvim_buf_set_option(bufnr, "filetype", "markdown")

		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal ysiwi")
		assert_buf_eq(bufnr, { "*test*" })

		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal ySb")
		assert_buf_eq(bufnr, { "***test***" })

		api.nvim_win_set_cursor(0, { 1, 3 })
		vim.cmd("normal ydi")
		assert_buf_eq(bufnr, { "**test**" })

		api.nvim_win_set_cursor(0, { 1, 3 })
		vim.cmd("normal ycbi")
		assert_buf_eq(bufnr, { "*test*" })
	end)

	it("can change emphasis keys", function()
		require("markdown").setup({
			inline_surround = {
				emphasis = { key = "q" },
				strong = { key = "w" },
				strikethrough = { key = "e" },
				code = { key = "r" },
			},
		})

		local bufnr = new_buf()
		api.nvim_buf_set_option(bufnr, "filetype", "markdown")

		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gsiwq")
		assert_buf_eq(bufnr, { "*test*" })

		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gsiww")
		assert_buf_eq(bufnr, { "**test**" })

		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gsiwe")
		assert_buf_eq(bufnr, { "~~test~~" })

		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gsiwr")
		assert_buf_eq(bufnr, { "`test`" })
	end)

	it("can change emphasis text", function()
		require("markdown").setup({
			inline_surround = {
				emphasis = { txt = "_" },
				strong = { txt = "__" },
				strikethrough = { txt = "~" },
				code = { txt = "```" },
			},
		})

		local bufnr = new_buf()
		api.nvim_buf_set_option(bufnr, "filetype", "markdown")

		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gsiwi")
		assert_buf_eq(bufnr, { "_test_" })
		vim.cmd("normal gsiwb")
		assert_buf_eq(bufnr, { "___test___" })
		vim.cmd("normal gsiws")
		assert_buf_eq(bufnr, { "~___test___~" })
		vim.cmd("normal ft")
		vim.cmd("normal gsiwc")
		assert_buf_eq(bufnr, { "~```___test___```~" })
	end)

	it("calls `on_attach`", function()
		local bufnr = new_buf()

		local attached_bufnr = -1
		local on_attach = function(b)
			attached_bufnr = b
		end

		require("markdown").setup({ on_attach = on_attach })
		api.nvim_buf_set_option(bufnr, "filetype", "markdown")

		assert.are.equal(bufnr, attached_bufnr)
	end)
end)
