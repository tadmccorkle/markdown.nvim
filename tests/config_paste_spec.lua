local api = vim.api

describe("config (paste handler)", function()
	it("can disable paste handler", function()
		require("markdown").setup({
			link = {
				paste = {
					enable = false,
				},
			},
		})

		local bufnr = api.nvim_create_buf(true, true)
		api.nvim_win_set_buf(0, bufnr)
		api.nvim_buf_set_option(bufnr, "filetype", "markdown")
		api.nvim_buf_set_lines(bufnr, 0, -1, false, { "test" })
		api.nvim_win_set_cursor(0, { 1, 1 })
		vim.cmd("normal viw")
		api.nvim_paste("https://example.com", true, -1)
		assert.are.same({ "https://example.com" }, api.nvim_buf_get_lines(bufnr, 0, -1, false))
	end)
end)
