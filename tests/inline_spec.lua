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

describe("inline", function()
	vim.cmd("runtime plugin/markdown.lua")
	require("markdown").setup()

	after_each(function()
		require("markdown.config"):reset()
	end)

	describe("toggle", function()
		describe("normal mode", function()
			it("toggles around motions", function()
				local bufnr = new_md_buf()
				set_buf(bufnr, {
					"block 1 line 1", "block 1 [line] 2", "block 1 line 3", "",
					"block 2 line 1", "block 2 line 2", "block 2 line 3",
				})
				api.nvim_win_set_cursor(0, { 1, 0 })
				vim.cmd("normal gsei")
				vim.cmd("normal fb")
				vim.cmd("normal gsiws")
				api.nvim_win_set_cursor(0, { 2, 0 })
				vim.cmd("normal gsiwb")
				vim.cmd("normal f[")
				vim.cmd("normal gsi[s")
				api.nvim_win_set_cursor(0, { 3, 0 })
				vim.cmd("normal gs8ei")
				api.nvim_win_set_cursor(0, { 6, 0 })
				vim.cmd("normal gsipc")
				set_buf(bufnr, {
					"~~*block*~~ 1 line 1", "**block** 1 [~~line~~] 2", "*block 1 line 3", "",
					"`block 2 line 1*", "block 2 line 2", "block 2 line 3`",
				})
				vim.cmd("normal gsipc")
				set_buf(bufnr, {
					"*block* 1 line 1", "**block** 1 [~~line~~] 2", "*block 1 line 3", "",
					"block 2 line 1*", "block 2 line 2", "block 2 line 3",
				})
				api.nvim_win_set_cursor(0, { 1, 3 })
				vim.cmd("normal gsiws")
				api.nvim_win_set_cursor(0, { 2, 2 })
				vim.cmd("normal gsiwb")
				vim.cmd("normal f[")
				vim.cmd("normal gsi[s")
				set_buf(bufnr, {
					"*block* 1 line 1", "block 1 [line] 2", "*block 1 line 3", "",
					"block 2 line 1*", "block 2 line 2", "block 2 line 3",
				})
			end)

			it("toggles around line motions", function()
				local bufnr = new_md_buf()
				set_buf(bufnr, {
					"block 1 line 1", "block 1 line 2", "block 1 line 3", "",
					"block 2 line 1", "block 2 line 2", "block 2 line 3",
				})
				api.nvim_win_set_cursor(0, { 2, 0 })
				vim.cmd("normal gs4js")
				assert_buf_eq(bufnr, {
					"block 1 line 1", "~~block 1 line 2", "block 1 line 3~~", "",
					"~~block 2 line 1", "block 2 line 2~~", "block 2 line 3",
				})
				vim.cmd("normal gs4jb")
				vim.cmd("normal gs4ji")
				assert_buf_eq(bufnr, {
					"block 1 line 1", "***~~block 1 line 2", "block 1 line 3~~***", "",
					"***~~block 2 line 1", "block 2 line 2~~***", "block 2 line 3",
				})
				vim.cmd("normal gs4js")
				vim.cmd("normal gs4jb")
				assert_buf_eq(bufnr, {
					"block 1 line 1", "*block 1 line 2", "block 1 line 3*", "",
					"*block 2 line 1", "block 2 line 2*", "block 2 line 3",
				})
				set_buf(bufnr, { "line of text" })
				api.nvim_win_set_cursor(0, { 1, 0 })
				vim.cmd("normal gssb")
				assert_buf_eq(bufnr, { "**line of text**" })
				vim.cmd("normal gsss")
				assert_buf_eq(bufnr, { "~~**line of text**~~" })
				vim.cmd("normal gssb")
				assert_buf_eq(bufnr, { "~~line of text~~" })
			end)

			it("can cancel toggle motion", function()
				local esc = api.nvim_replace_termcodes("<Esc>", true, false, true)

				local bufnr = new_md_buf()
				set_buf(bufnr, { "line of text" })
				api.nvim_win_set_cursor(0, { 1, 0 })
				vim.cmd("normal gsiw" .. esc .. "A continue edits" .. esc)
				assert_buf_eq(bufnr, { "line of text continue edits" })
			end)

			it("handles invalid toggle key", function()
				local esc = api.nvim_replace_termcodes("<Esc>", true, false, true)

				local bufnr = new_md_buf()
				set_buf(bufnr, { "line of text" })
				api.nvim_win_set_cursor(0, { 1, 0 })
				vim.cmd("normal gsiwlA continue edits" .. esc)
				assert_buf_eq(bufnr, { "line of text continue edits" })
			end)
		end)

		describe("visual mode", function()
			it("toggles around visual selection", function()
				local bufnr = new_md_buf()
				set_buf(bufnr, {
					"block 1 line 1", "block 1 line 2", "block 1 line 3", "",
					"block 2 line 1", "block 2 line 2", "block 2 line 3",
				})
				api.nvim_win_set_cursor(0, { 1, 8 })
				vim.cmd("normal v6j2ge")
				vim.cmd("normal gsb")
				vim.cmd("normal gve")
				vim.cmd("normal gss")
				assert_buf_eq(bufnr, {
					"block 1 ~~**line 1", "block 1 line 2", "block 1 line 3**~~", "",
					"~~**block 2 line 1", "block 2 line 2", "block**~~ 2 line 3",
				})
				vim.cmd("normal gv")
				vim.cmd("normal gsb")
				assert_buf_eq(bufnr, {
					"block 1 ~~line 1", "block 1 line 2", "block 1 line 3~~", "",
					"~~block 2 line 1", "block 2 line 2", "block~~ 2 line 3",
				})
				vim.cmd("normal gv")
				vim.cmd("normal gss")
				assert_buf_eq(bufnr, {
					"block 1 line 1", "block 1 line 2", "block 1 line 3", "",
					"block 2 line 1", "block 2 line 2", "block 2 line 3",
				})

				set_buf(bufnr, {
					"block line", "- list", "- list 1 item 3", "- list 1 item 4",
				})
				api.nvim_win_set_cursor(0, { 1, 0 })
				vim.cmd("normal wv2je")
				vim.cmd("normal gsb")
				vim.cmd("normal gv")
				vim.cmd("normal gsi")
				assert_buf_eq(bufnr, {
					"block ***line***", "- ***list***", "- ***list 1*** item 3", "- list 1 item 4",
				})
				vim.cmd("normal gv")
				vim.cmd("normal gsi")
				assert_buf_eq(bufnr, {
					"block **line**", "- **list**", "- **list 1** item 3", "- list 1 item 4",
				})
				vim.cmd("normal gv")
				vim.cmd("normal gsb")
				assert_buf_eq(bufnr, {
					"block line", "- list", "- list 1 item 3", "- list 1 item 4",
				})
			end)

			it("toggles around visual line selection", function()
				local bufnr = new_md_buf()
				set_buf(bufnr, {
					"block 1 line 1", "block 1 line 2", "block 1 line 3", "",
					"block 2 line 1", "block 2 line 2", "block 2 line 3",
				})
				api.nvim_win_set_cursor(0, { 1, 1 })
				vim.cmd("normal V6j")
				vim.cmd("normal gsb")
				vim.cmd("normal gv")
				vim.cmd("normal gss")
				assert_buf_eq(bufnr, {
					"~~**block 1 line 1", "block 1 line 2", "block 1 line 3**~~", "",
					"~~**block 2 line 1", "block 2 line 2", "block 2 line 3**~~",
				})
				vim.cmd("normal gv")
				vim.cmd("normal gsb")
				assert_buf_eq(bufnr, {
					"~~block 1 line 1", "block 1 line 2", "block 1 line 3~~", "",
					"~~block 2 line 1", "block 2 line 2", "block 2 line 3~~",
				})
				vim.cmd("normal gv")
				vim.cmd("normal gss")
				assert_buf_eq(bufnr, {
					"block 1 line 1", "block 1 line 2", "block 1 line 3", "",
					"block 2 line 1", "block 2 line 2", "block 2 line 3",
				})

				set_buf(bufnr, {
					"block line", "- list", "- list 1 item 3", "- list 1 item 4",
				})
				api.nvim_win_set_cursor(0, { 1, 0 })
				vim.cmd("normal V2j")
				vim.cmd("normal gsb")
				vim.cmd("normal gv")
				vim.cmd("normal gsi")
				assert_buf_eq(bufnr, {
					"***block line***", "- ***list***", "- ***list 1 item 3***", "- list 1 item 4",
				})
				vim.cmd("normal gv")
				vim.cmd("normal gsi")
				assert_buf_eq(bufnr, {
					"**block line**", "- **list**", "- **list 1 item 3**", "- list 1 item 4",
				})
				vim.cmd("normal gv")
				vim.cmd("normal gsb")
				assert_buf_eq(bufnr, {
					"block line", "- list", "- list 1 item 3", "- list 1 item 4",
				})
			end)

			it("toggles around visual block", function()
				local ctrl_v = api.nvim_replace_termcodes("<C-v>", true, false, true)

				local bufnr = new_md_buf()
				set_buf(bufnr, {
					"block 1 line 1", "block 1 line 2", "block 1 line 3", "",
					"block 2 line 1", "block 2 line 2", "block 2 line 3",
				})
				api.nvim_win_set_cursor(0, { 1, 8 })
				vim.cmd("normal " .. ctrl_v .. "6je")
				vim.cmd("normal gsb")
				vim.cmd("normal gve")
				vim.cmd("normal gss")
				assert_buf_eq(bufnr, {
					"block 1 ~~**line**~~ 1", "block 1 ~~**line**~~ 2", "block 1 ~~**line**~~ 3", "",
					"block 2 ~~**line**~~ 1", "block 2 ~~**line**~~ 2", "block 2 ~~**line**~~ 3",
				})
				vim.cmd("normal gv")
				vim.cmd("normal gsb")
				assert_buf_eq(bufnr, {
					"block 1 ~~line~~ 1", "block 1 ~~line~~ 2", "block 1 ~~line~~ 3", "",
					"block 2 ~~line~~ 1", "block 2 ~~line~~ 2", "block 2 ~~line~~ 3",
				})
				vim.cmd("normal gv")
				vim.cmd("normal gss")
				assert_buf_eq(bufnr, {
					"block 1 line 1", "block 1 line 2", "block 1 line 3", "",
					"block 2 line 1", "block 2 line 2", "block 2 line 3",
				})

				set_buf(bufnr, {
					"block line", "- list", "- list 1 item 3", "- list 1 item 4",
				})
				api.nvim_win_set_cursor(0, { 1, 0 })
				vim.cmd("normal " .. ctrl_v .. "2j3e")
				vim.cmd("normal gsb")
				vim.cmd("normal gv")
				vim.cmd("normal gsi")
				assert_buf_eq(bufnr, {
					"***block line***", "- ***list***", "- ***list 1 item*** 3", "- list 1 item 4",
				})
				vim.cmd("normal gv")
				vim.cmd("normal gsi")
				assert_buf_eq(bufnr, {
					"**block line**", "- **list**", "- **list 1 item** 3", "- list 1 item 4",
				})
				vim.cmd("normal gv")
				vim.cmd("normal gsb")
				assert_buf_eq(bufnr, {
					"block line", "- list", "- list 1 item 3", "- list 1 item 4",
				})
			end)

			it("leaves visual mode on success", function()
				local bufnr = new_md_buf()
				set_buf(bufnr, { "text" })
				vim.cmd("normal viwgsi")
				vim.cmd("normal a continues")
				assert_buf_eq(bufnr, { "*text continues*" })
			end)

			it("stays in visual mode on failure", function()
				local bufnr = new_md_buf()
				set_buf(bufnr, { "text" })
				vim.cmd("normal viwgsjcnew text")
				assert_buf_eq(bufnr, { "new text" })
			end)
		end)

		it("toggles within containers", function()
			local bufnr = new_md_buf()
			set_buf(bufnr, {
				"a normal",
				"markdown block",
				"",
				"- a list block",
				"  * with child",
				"  * items",
				"- followed by",
				"",
				"> a block",
				"> quote and",
				"",
				"> - a list in",
				"> - block quotes",
			})
			api.nvim_win_set_cursor(0, { 2, 0 })
			vim.cmd("normal gs10jb")
			assert_buf_eq(0, {
				"a normal",
				"**markdown block**",
				"",
				"- **a list block**",
				"  * **with child**",
				"  * **items**",
				"- **followed by**",
				"",
				"> **a block",
				"> quote and**",
				"",
				"> - **a list in**",
				"> - block quotes",
			})
			api.nvim_win_set_cursor(0, { 2, 2 })
			vim.cmd("normal gs40wi")
			assert_buf_eq(0, {
				"a normal",
				"***markdown block***",
				"",
				"- ***a list block***",
				"  * ***with child***",
				"  * ***items***",
				"- ***followed by***",
				"",
				"> ***a block",
				"> quote and***",
				"",
				"> - ***a list in***",
				"> - block quotes",
			})
			api.nvim_win_set_cursor(0, { 5, 0 })
			vim.cmd("normal gsss")
			assert_buf_eq(0, {
				"a normal",
				"***markdown block***",
				"",
				"- ***a list block***",
				"  * ~~***with child***~~",
				"  * ***items***",
				"- ***followed by***",
				"",
				"> ***a block",
				"> quote and***",
				"",
				"> - ***a list in***",
				"> - block quotes",
			})
			api.nvim_win_set_cursor(0, { 4, 0 })
			vim.cmd("normal gs6jb")
			assert_buf_eq(0, {
				"a normal",
				"***markdown block***",
				"",
				"- *a list block*",
				"  * ~~*with child*~~",
				"  * *items*",
				"- *followed by*",
				"",
				"> *a block",
				"> quote and*",
				"",
				"> - ***a list in***",
				"> - block quotes",
			})
		end)

		it("toggles single and double strikethrough", function()
			local bufnr = new_md_buf()

			set_buf(bufnr, { "~test~" })
			api.nvim_win_set_cursor(0, { 1, 1 })
			vim.cmd("normal gsiws")
			assert_buf_eq(bufnr, { "test" })
			vim.cmd("normal gsiws")
			assert_buf_eq(bufnr, { "~~test~~" })

			require("markdown").setup({ inline_surround = { strikethrough = { txt = "~" } } })
			api.nvim_win_set_cursor(0, { 1, 2 })
			vim.cmd("normal gsiws")
			assert_buf_eq(bufnr, { "test" })
			vim.cmd("normal gsiws")
			assert_buf_eq(bufnr, { "~test~" })
		end)
	end)

	describe("delete", function()
		it("deletes surrounding emphasis", function()
			local bufnr = new_md_buf()
			set_buf(bufnr, { "~~test~~", "**test**", "*test*", "`test`" })
			api.nvim_win_set_cursor(0, { 1, 3 })
			vim.cmd("normal dssjdsbjdsijdsc")
			assert_buf_eq(bufnr, { "test", "test", "test", "test" })
		end)

		it("deletes single and double strikethough", function()
			local bufnr = new_md_buf()

			set_buf(bufnr, { "~~test~~" })
			api.nvim_win_set_cursor(0, { 1, 3 })
			vim.cmd("normal dss")
			assert_buf_eq(bufnr, { "test" })
			set_buf(bufnr, { "~test~" })
			api.nvim_win_set_cursor(0, { 1, 3 })
			vim.cmd("normal dss")
			assert_buf_eq(bufnr, { "test" })

			require("markdown").setup({ inline_surround = { strikethrough = { txt = "~" } } })
			set_buf(bufnr, { "~test~" })
			api.nvim_win_set_cursor(0, { 1, 3 })
			vim.cmd("normal dss")
			assert_buf_eq(bufnr, { "test" })
			set_buf(bufnr, { "~~test~~" })
			api.nvim_win_set_cursor(0, { 1, 3 })
			vim.cmd("normal dss")
			assert_buf_eq(bufnr, { "test" })
		end)

		it("only deletes directly surrounding emphasis", function()
			local bufnr = new_md_buf()

			set_buf(bufnr, { "~test ~test~ test~" })
			api.nvim_win_set_cursor(0, { 1, 10 })
			vim.cmd("normal dss")
			assert_buf_eq(bufnr, { "~test test test~" })

			set_buf(bufnr, { "**test* test* test" })
			api.nvim_win_set_cursor(0, { 1, 3 })
			vim.cmd("normal dsi")
			assert_buf_eq(bufnr, { "*test test* test" })
		end)
	end)

	describe("change", function()
		it("changes surrounding emphasis", function()
			local bufnr = new_md_buf()
			set_buf(bufnr, { "~~test~~", "**test**", "*test*", "`test`" })
			api.nvim_win_set_cursor(0, { 1, 3 })
			vim.cmd("normal cssijcsbcjcsibjcscs")
			assert_buf_eq(bufnr, { "*test*", "`test`", "**test**", "~~test~~" })
		end)

		it("changes single and double strikethough", function()
			local bufnr = new_md_buf()

			set_buf(bufnr, { "~~test~~" })
			api.nvim_win_set_cursor(0, { 1, 3 })
			vim.cmd("normal cssi")
			assert_buf_eq(bufnr, { "*test*" })
			set_buf(bufnr, { "~test~" })
			api.nvim_win_set_cursor(0, { 1, 3 })
			vim.cmd("normal cssi")
			assert_buf_eq(bufnr, { "*test*" })

			require("markdown").setup({ inline_surround = { strikethrough = { txt = "~" } } })
			set_buf(bufnr, { "~test~" })
			api.nvim_win_set_cursor(0, { 1, 3 })
			vim.cmd("normal cssi")
			assert_buf_eq(bufnr, { "*test*" })
			set_buf(bufnr, { "~~test~~" })
			api.nvim_win_set_cursor(0, { 1, 3 })
			vim.cmd("normal cssi")
			assert_buf_eq(bufnr, { "*test*" })
		end)

		it("only changes directly surrounding emphasis", function()
			local bufnr = new_md_buf()

			set_buf(bufnr, { "~test ~test~ test~" })
			api.nvim_win_set_cursor(0, { 1, 10 })
			vim.cmd("normal cssi")
			assert_buf_eq(bufnr, { "~test *test* test~" })

			set_buf(bufnr, { "**test* test* test" })
			api.nvim_win_set_cursor(0, { 1, 3 })
			vim.cmd("normal csic")
			assert_buf_eq(bufnr, { "*`test` test* test" })
		end)
	end)
end)
