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

describe("issues", function()
	vim.cmd("runtime plugin/markdown.lua")
	require("markdown").setup()

	it("can support chinese characters (#11)", function()
		local bufnr = new_md_buf()

		-- link around visual selection
		set_buf(bufnr, { "### 掉鏈子" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal wvegl")
		assert_buf_eq(bufnr, { "### [掉鏈子]()" })

		-- toggle emphasis around visual selection
		set_buf(bufnr, {
			"我们在这里过得很开心",
			"短暂的一段时间",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("normal vegsi")
		assert_buf_eq(bufnr, {
			"*我们在这里过得很开心*",
			"短暂的一段时间",
		})
		vim.cmd("normal gvgsi")
		assert_buf_eq(bufnr, {
			"我们在这里过得很开心",
			"短暂的一段时间",
		})

		-- toggle emphasis around line motions
		set_buf(bufnr, {
			"我们在这里过得很开心",
			"短暂的一段时间",
		})
		api.nvim_win_set_cursor(0, { 1, 0 })
		vim.cmd("normal gssb")
		assert_buf_eq(bufnr, {
			"**我们在这里过得很开心**",
			"短暂的一段时间",
		})
		vim.cmd("normal gsji")
		assert_buf_eq(bufnr, {
			"***我们在这里过得很开心**",
			"短暂的一段时间*",
		})
	end)
end)
