local api = vim.api

local function new_md_buf()
	local bufnr = api.nvim_create_buf(true, true)
	api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
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

	local link = require("markdown.link")

	it("can add over motion", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal gliw")
		assert_buf_eq(bufnr, { "[test]()" })
		vim.cmd("normal adestination")
		assert_buf_eq(bufnr, { "[test](destination)" })

		set_buf(bufnr, { "asdf 👌🥲🤌 我 Ü fdsa" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal wglfa")
		assert_buf_eq(bufnr, { "asdf [👌🥲🤌 我 Ü fdsa]()" })
	end)

	it("can add over visual selection", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal vlgl")
		assert_buf_eq(bufnr, { "t[es]()t" })
		vim.cmd("normal adestination")
		assert_buf_eq(bufnr, { "t[es](destination)t" })

		set_buf(bufnr, { "asdf 👌🥲🤌 我 Ü fdsa" })
		api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("normal llveeeelllgl")
		assert_buf_eq(bufnr, { "as[df 👌🥲🤌 我 Ü fd]()sa" })
	end)

	it("can follow headings", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			"[test](#test)",
			"# Test~`!@#$%^&*(){[|\\<,>.?/]}-2",
			"## Test",
			"[test2](#test-2)",
		})
		api.nvim_win_set_cursor(0, { 1, 1 })
		link.follow()
		assert.are.same({ 3, 0 }, api.nvim_win_get_cursor(0))
		vim.cmd("normal j")
		link.follow()
		assert.are.same({ 2, 0 }, api.nvim_win_get_cursor(0))
	end)

	it("can follow duplicate headings in another file", function()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		dir = vim.uv.fs_realpath(dir)
		local target = dir .. "/target.md"
		vim.fn.writefile({ "# Same", "# Same", "# Same 1" }, target)
		local bufnr = new_md_buf()
		api.nvim_buf_set_name(bufnr, dir .. "/source.md")
		set_buf(bufnr, { "[second](./target.md#same-1-1)" })
		api.nvim_win_set_cursor(0, { 1, 4 })
		local ok, err = pcall(link.follow)
		local actual_path = api.nvim_buf_get_name(0)
		local actual_cursor = api.nvim_win_get_cursor(0)
		local target_buf = api.nvim_get_current_buf()
		api.nvim_win_set_buf(0, bufnr)
		if target_buf ~= bufnr then
			api.nvim_buf_delete(target_buf, { force = true })
		end
		vim.fn.delete(dir, "rf")
		assert.is_true(ok, err)
		assert.are.same(vim.fs.normalize(target), vim.fs.normalize(actual_path))
		assert.are.same({ 3, 0 }, actual_cursor)
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
