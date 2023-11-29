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

describe("nav", function()
	local nav = require("markdown.nav")

	it("can go to current heading", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			--[[1]] "top-level section",
			--[[2]] "",
			--[[3]] "# heading 1",
			--[[4]] "",
			--[[5]] "## heading 2",
			--[[6]] "",
			--[[7]] "- # heading in container",
			--[[8]] "",
		})

		-- ignores headings in containers
		api.nvim_win_set_cursor(0, { 8, 0 })
		nav.curr_heading()
		assert.are.same({ 5, 0 }, api.nvim_win_get_cursor(0))

		-- stays at current heading
		nav.curr_heading()
		assert.are.same({ 5, 0 }, api.nvim_win_get_cursor(0))

		-- handles top-level sections (i.e., no heading)
		api.nvim_win_set_cursor(0, { 2, 0 })
		nav.curr_heading()
		assert.are.same({ 2, 0 }, api.nvim_win_get_cursor(0))
	end)

	it("can go to parent heading", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			--[[01]] "top-level section",
			--[[02]] "",
			--[[03]] "# heading 1",
			--[[04]] "",
			--[[05]] "## heading 1",
			--[[06]] "",
			--[[07]] "- # heading in container",
			--[[08]] "",
			--[[09]] "### heading 3",
			--[[10]] "## heading 4",
		})

		-- ignores headings in containers
		api.nvim_win_set_cursor(0, { 9, 0 })
		nav.parent_heading()
		assert.are.same({ 5, 0 }, api.nvim_win_get_cursor(0))

		-- goes to parent when within current heading section
		api.nvim_win_set_cursor(0, { 6, 0 })
		nav.parent_heading()
		assert.are.same({ 3, 0 }, api.nvim_win_get_cursor(0))

		-- ignores sibling headings
		api.nvim_win_set_cursor(0, { 10, 0 })
		nav.parent_heading()
		assert.are.same({ 3, 0 }, api.nvim_win_get_cursor(0))

		-- handles top-level sections (i.e., no heading)
		api.nvim_win_set_cursor(0, { 2, 0 })
		nav.parent_heading()
		assert.are.same({ 2, 0 }, api.nvim_win_get_cursor(0))
	end)

	it("can go to next heading", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			--[[1]] "top-level section",
			--[[2]] "",
			--[[3]] "# heading 1",
			--[[4]] "",
			--[[5]] "## heading 2",
			--[[6]] "",
			--[[7]] "- # heading in container",
			--[[8]] "",
			--[[9]] "### heading 3",
		})

		api.nvim_win_set_cursor(0, { 1, 0 })
		nav.next_heading()
		assert.are.same({ 3, 0 }, api.nvim_win_get_cursor(0))

		nav.next_heading()
		assert.are.same({ 5, 0 }, api.nvim_win_get_cursor(0))

		-- ignores headings in containers
		nav.next_heading()
		assert.are.same({ 9, 0 }, api.nvim_win_get_cursor(0))

		nav.next_heading()
		assert.are.same({ 9, 0 }, api.nvim_win_get_cursor(0))
	end)

	it("can go to previous heading", function()
		local bufnr = new_md_buf()
		set_buf(bufnr, {
			--[[01]] "top-level section",
			--[[02]] "",
			--[[03]] "# heading 1",
			--[[04]] "",
			--[[05]] "## heading 2",
			--[[06]] "",
			--[[07]] "- # heading in container",
			--[[08]] "",
			--[[09]] "### heading 3",
			--[[10]] "",
		})

		-- ignores headings in containers
		api.nvim_win_set_cursor(0, { 10, 0 })
		nav.prev_heading()
		assert.are.same({ 5, 0 }, api.nvim_win_get_cursor(0))

		nav.prev_heading()
		assert.are.same({ 3, 0 }, api.nvim_win_get_cursor(0))

		nav.prev_heading()
		assert.are.same({ 3, 0 }, api.nvim_win_get_cursor(0))
	end)
end)
