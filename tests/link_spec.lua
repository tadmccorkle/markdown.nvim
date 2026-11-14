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

	local function paste(text, selection, lines)
		local bufnr = new_md_buf()
		set_buf(bufnr, lines or { "test" })
		api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("normal! " .. (selection or "viw"))
		api.nvim_paste(text, true, -1)
		return bufnr
	end

	for _, dest in ipairs({
		"https://example.com",
		"http://example.com",
		"www.example.com",
		"mailto:example@example.org",
		"mailto:example@example.org?subject=Hello%20there",
		"file:///tmp/document%20name.pdf#L3",
		"tel:+123456789",
		"git+ssh://example.org/repo",
		"my-app.v2:resource",
		"HTTPS://example.org/a?q=one%20two#fragment",
	}) do
		it("can paste a link destination: " .. dest, function()
			assert_buf_eq(paste(dest), { "[test](" .. dest .. ")" })
		end)
	end

	for _, text in ipairs({
		"C:/notes/file.md",
		"C:\\notes\\file.md",
		"./notes/file.md",
		"plain text",
		"note: some prose",
		"file:///tmp/document name.pdf",
		"https://example.org/a b",
	}) do
		it("pastes non-URI text literally: " .. text, function()
			assert_buf_eq(paste(text), { text })
		end)
	end

	it("can paste a URI over a linewise selection", function()
		assert_buf_eq(paste("mailto:a@example.org", "V"), { "[test](mailto:a@example.org)" })
	end)

	it("does not convert multiline URI paste", function()
		local lines = { "mailto:a@example.org", "mailto:b@example.org" }
		assert_buf_eq(paste(table.concat(lines, "\n")), lines)
	end)

	for _, case in ipairs({
		{ "a visual block selection", "\22lll" },
		{ "multiple inline blocks", "vG$", { "first", "", "last" } },
	}) do
		it("does not convert URI paste over " .. case[1], function()
			assert_buf_eq(paste("mailto:a@example.org", case[2], case[3]), { "mailto:a@example.org" })
		end)
	end
end)
