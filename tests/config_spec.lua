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

describe("config", function()
	vim.cmd("runtime plugin/markdown.lua")

	before_each(function()
		require("markdown.config"):reset()
	end)

	it("can disable all inline surround mappings", function()
		require("markdown").setup({ inline_surround = { mappings = false } })

		local bufnr = new_md_buf()

		set_buf(bufnr, { "*test*" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gsiwi")
		assert_buf_eq(bufnr, { "*witest*" })

		set_buf(bufnr, { "*test*" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gssi")
		assert_buf_eq(bufnr, { "*iest*" })

		set_buf(bufnr, { "*test*" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal dsi")
		assert_buf_eq(bufnr, { "*test*" })

		set_buf(bufnr, { "*test*" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal csib")
		assert_buf_eq(bufnr, { "*test*" })
	end)

	it("can disable inline surround mappings selectively", function()
		require("markdown").setup({ inline_surround = { mappings = { toggle = false } } })

		local bufnr = new_md_buf()
		set_buf(bufnr, { "*test*" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gsiwi")
		assert_buf_eq(bufnr, { "*witest*" })
		vim.cmd("normal gssi")
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

		local bufnr = new_md_buf()
		set_buf(bufnr, { "test" })

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

		local bufnr = new_md_buf()

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

		local bufnr = new_md_buf()

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
		local attached_bufnr = -1
		require("markdown").setup({
			on_attach = function(b)
				attached_bufnr = b
			end
		})

		local bufnr = new_md_buf()
		assert.are.equal(bufnr, attached_bufnr)
		assert.are_not.equal(-1, attached_bufnr)
	end)
end)
