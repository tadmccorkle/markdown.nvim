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

	it("can disable all mappings", function()
		require("markdown").setup({ mappings = false })

		local bufnr = new_md_buf()

		set_buf(bufnr, { "*test*" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gsiwi")
		assert_buf_eq(bufnr, { "*witest*" })

		set_buf(bufnr, { "*test*" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gssi")
		assert_buf_eq(bufnr, { "*iest*" })
	end)

	it("can disable mappings selectively", function()
		require("markdown").setup({ mappings = { inline_surround_toggle = false } })

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
			mappings = {
				inline_surround_toggle = "ys",
				inline_surround_toggle_line = "yS",
				inline_surround_delete = "yd",
				inline_surround_change = "yc",
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

	it("can change link mappings", function()
		require("markdown").setup({
			mappings = {
				link_add = "yx",
				link_follow = "yy",
			},
		})

		local bufnr = new_md_buf()

		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal yxiw")
		assert_buf_eq(bufnr, { "[test]()" })

		set_buf(bufnr, { "[test](#test)", "", "# test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal yy")
		assert.are.same({ 3, 0 }, api.nvim_win_get_cursor(0))
	end)

	it("can change toc omit flags", function()
		require("markdown").setup({
			toc = {
				omit_heading = "asdf",
				omit_section = "qwer",
			},
		})

		local bufnr = new_md_buf()

		set_buf(bufnr, { "# test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("MDInsertToc")
		assert_buf_eq(bufnr, { "- [test](#test)", "# test" })

		set_buf(bufnr, { "# test <!-- asdf -->" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("MDInsertToc")
		assert_buf_eq(bufnr, { "# test <!-- asdf -->" })

		set_buf(bufnr, { "# test <!-- qwer -->" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("MDInsertToc")
		assert_buf_eq(bufnr, { "# test <!-- qwer -->" })
	end)

	it("can change toc list markers", function()
		require("markdown").setup({
			toc = {
				markers = { "+" },
			},
		})

		local bufnr = new_md_buf()

		set_buf(bufnr, { "# test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("MDInsertToc")
		assert_buf_eq(bufnr, { "+ [test](#test)", "# test" })
	end)

	it("can extend link following behavior", function()
		local last_dest
		require("markdown").setup({
			hooks = {
				follow_link = function(opts, fallback)
					last_dest = opts.dest
					if opts.dest ~= "#1" then
						fallback()
					end
				end,
			},
		})

		local bufnr = new_md_buf()
		set_buf(bufnr, { "[test](#1)", "[test](#2)", "# 1", "# 2" })

		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gx")
		assert.are.same({ 1, 1 }, api.nvim_win_get_cursor(0))
		assert.are.equal("#1", last_dest)

		api.nvim_win_set_cursor(0, { 2, 1 })
		vim.cmd("normal gx")
		assert.are.same({ 4, 0 }, api.nvim_win_get_cursor(0))
		assert.are.equal("#2", last_dest)
	end)

	it("can change navigation mappings", function()
		require("markdown").setup({
			mappings = {
				go_curr_heading = "[a",
				go_parent_heading = "[b",
				go_next_heading = "[c",
				go_prev_heading = "[d",
			}
		})

		local bufnr = new_md_buf()
		set_buf(bufnr, { "# test", "## test1", "", "## test2" })

		api.nvim_win_set_cursor(0, { 3, 0 })
		vim.cmd("normal [a")
		assert.are.same({ 2, 0 }, api.nvim_win_get_cursor(0))

		api.nvim_win_set_cursor(0, { 3, 0 })
		vim.cmd("normal [b")
		assert.are.same({ 1, 0 }, api.nvim_win_get_cursor(0))

		api.nvim_win_set_cursor(0, { 3, 0 })
		vim.cmd("normal [c")
		assert.are.same({ 4, 0 }, api.nvim_win_get_cursor(0))

		api.nvim_win_set_cursor(0, { 3, 0 })
		vim.cmd("normal [d")
		assert.are.same({ 1, 0 }, api.nvim_win_get_cursor(0))
	end)

	it("calls 'on_attach'", function()
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
