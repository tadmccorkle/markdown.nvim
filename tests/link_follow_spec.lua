local api = vim.api
local markdown = require("markdown")
local config = require("markdown.config")
local notify = require("markdown.notify")

local function gx(keys)
	vim.cmd("normal " .. (keys or "gx"))
	api.nvim_feedkeys("", "x", false)
end

describe("link following and native fallback", function()
	local bufnr, opened, messages, errors, followed, overrides, global_gx

	vim.cmd("runtime plugin/markdown.lua")

	-- Restore every override in teardown, including when the assertion or gx fails.
	local function override(tbl, key, value)
		table.insert(overrides, { tbl, key, tbl[key] })
		tbl[key] = value
	end

	local function fallback(buf, lhs)
		vim.keymap.set("n", lhs or "gx", function()
			followed = followed + 1
		end, { buffer = buf })
	end

	local function attach(lines, mapping)
		bufnr = api.nvim_create_buf(true, true)
		api.nvim_win_set_buf(0, bufnr)
		api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		if mapping then
			mapping(bufnr)
		end
		api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
		api.nvim_win_set_cursor(0, { 1, 1 })
		-- Native 0.12 gx consults the active highlighter's tree as well.
		vim.treesitter.get_parser(bufnr, "markdown"):parse()
	end

	before_each(function()
		config:reset()
		markdown.setup()
		global_gx = vim.fn.maparg("gx", "n", false, true)
		opened, messages, errors, followed, overrides = {}, {}, {}, 0, {}
		override(vim.ui, "open", function(dest)
			table.insert(opened, dest)
		end)
		override(notify, "info", function(message)
			table.insert(messages, message)
		end)
		override(notify, "error", function(message)
			table.insert(errors, message)
		end)
	end)

	after_each(function()
		for i = #overrides, 1, -1 do
			local saved = overrides[i]
			saved[1][saved[2]] = saved[3]
		end
		if bufnr and api.nvim_buf_is_valid(bufnr) then
			api.nvim_buf_delete(bufnr, { force = true })
		end
		if next(global_gx) ~= nil then
			vim.fn.mapset("n", false, global_gx)
		end
		vim.g.markdown_test_follow = nil
		config:reset()
	end)

	for _, dest in ipairs({
		"mailto:example@example.org",
		"mailto:example@example.org?subject=Hello%20there",
		"file:///not-present/document%20name.pdf#L3",
		"tel:+123456789",
		"git+ssh://example.org/repo",
		"my-app.v2:resource",
		"HTTPS://example.org/a?q=one%20two#fragment",
		"https://example.org/a?q=one%20two#fragment",
		"http://example.org",
	}) do
		it("opens URI unchanged: " .. dest, function()
			attach({ "[target](" .. dest .. ")" })
			gx()
			assert.are.same({ dest }, opened)
			assert.are.same({}, messages)
		end)
	end

	it("keeps www shorthand", function()
		attach({ "[target](www.example.org)" })
		gx()
		assert.are.same({ "https://www.example.org" }, opened)
	end)

	it("delegates bare URLs to native gx", function()
		attach({ "https://example.org/test" })
		gx()
		assert.are.same({ "https://example.org/test" }, opened)
	end)

	it("delegates bare directories to native gx", function()
		local dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		attach({ dir })
		gx()
		vim.fn.delete(dir, "rf")
		assert.are.same({ vim.fs.normalize(dir) }, opened)
	end)

	it("preserves a buffer-local Lua callback across repeated setup", function()
		attach({ "plain text" }, fallback)
		markdown.setup()
		markdown.setup()
		gx()
		assert.are.same(1, followed)
		assert.are.same({}, opened)
	end)

	it("does not delegate a plugin mapping to itself", function()
		attach({ "plain text" }, function(buf)
			vim.keymap.set("n", "gx", "<Plug>(markdown_follow_link)", { buffer = buf })
		end)
		gx()
		assert.are.same({}, opened)
	end)

	it("preserves expression mappings", function()
		attach({ "plain text" }, function(buf)
			vim.keymap.set("n", "gx", function()
				return "<Cmd>let g:markdown_test_follow = 42<CR>"
			end, { buffer = buf, expr = true })
		end)
		gx()
		assert.are.same(42, vim.g.markdown_test_follow)
	end)

	it("preserves remapped string mappings", function()
		attach({ "plain text" }, function(buf)
			vim.keymap.set("n", "<Plug>(markdown_test_follow)", function()
				vim.g.markdown_test_follow = 42
			end, { buffer = buf })
			vim.keymap.set("n", "gx", "<Plug>(markdown_test_follow)", { buffer = buf })
		end)
		gx()
		assert.are.same(42, vim.g.markdown_test_follow)
	end)

	it("preserves script-local string mappings", function()
		attach({ "plain text" }, function(buf)
			api.nvim_buf_call(buf, function()
				vim.cmd([[
					function! s:Follow() abort
						let g:markdown_test_follow = 42
					endfunction
					nnoremap <buffer> gx <Cmd>call <SID>Follow()<CR>
				]])
			end)
		end)
		gx()
		assert.are.same(42, vim.g.markdown_test_follow)
	end)

	it("uses the configured follow key's previous mapping", function()
		markdown.setup({ mappings = { link_follow = "go" } })
		attach({ "plain text" }, function(buf)
			fallback(buf, "go")
		end)
		gx("go")
		assert.are.same(1, followed)
	end)

	it("preserves global custom mappings", function()
		vim.keymap.set("n", "gx", "<Cmd>let g:markdown_test_follow = 42<CR>")
		attach({ "plain text" })
		gx()
		assert.are.same(42, vim.g.markdown_test_follow)
	end)

	it("does not recreate an absent mapping", function()
		vim.keymap.del("n", "gx")
		attach({ "https://example.org" })
		gx()
		assert.are.same({}, opened)
	end)

	it("falls back when the parser fails", function()
		attach({ "https://example.org" }, fallback)
		override(vim.treesitter, "get_parser", function()
			error("parser unavailable")
		end)
		gx()
		assert.are.same(1, followed)
	end)

	for _, dest in ipairs({ "", "#missing", "./missing-file", "C:/missing-file", "C:\\missing" }) do
		it("does not fall back for a recognized link: " .. dest, function()
			attach({ "[target](" .. dest .. ")" }, fallback)
			gx()
			assert.are.same(0, followed)
			assert.are.same({}, opened)
		end)
	end

	it("reports URI opener failures", function()
		attach({ "[mail](mailto:example@example.org)" })
		override(vim.ui, "open", function()
			return nil, "no handler"
		end)
		gx()
		assert.are.same({ "URL navigation failed. no handler" }, errors)
	end)

	it("keeps native fallback outside the follow hook", function()
		local destinations = {}
		markdown.setup({
			hooks = {
				follow_link = function(opts, follow)
					table.insert(destinations, opts.dest)
					follow()
				end,
			},
		})
		attach({ "https://example.org", "[mail](mailto:a@example.org)" })
		gx()
		api.nvim_win_set_cursor(0, { 2, 1 })
		gx()
		assert.are.same({ "mailto:a@example.org" }, destinations)
		assert.are.same({ "https://example.org", "mailto:a@example.org" }, opened)
	end)

	it("leaves gx intact when its mapping is disabled", function()
		markdown.setup({ mappings = { link_follow = false } })
		attach({ "https://example.org" })
		assert.are.same(0, vim.fn.maparg("gx", "n", false, true).buffer)
		gx()
		assert.are.same({ "https://example.org" }, opened)
	end)

	it("leaves visual gx intact", function()
		attach({ "https://example.org" })
		gx("0v$gx")
		assert.are.same({ "https://example.org" }, opened)
	end)

	if vim.fn.has("nvim-0.12") == 1 then
		it("delegates LSP document links, including multiple targets", function()
			attach({ "label" })
			local client = {
				id = 1,
				offset_encoding = "utf-16",
				supports_method = function()
					return true
				end,
			}
			local range = {
				start = { line = 0, character = 0 },
				["end"] = { line = 0, character = 5 },
			}
			local links = {
				{ range = range, target = "mailto:hidden@example.org" },
				{ range = range, target = "https://example.org" },
			}
			override(vim.lsp, "get_clients", function()
				return { client }
			end)
			override(vim.lsp, "get_client_by_id", function()
				return client
			end)
			override(vim.lsp, "buf_request_sync", function()
				return { [1] = { result = links } }
			end)
			gx()
			assert.are.same({ "mailto:hidden@example.org", "https://example.org" }, opened)
		end)
	end

	if vim.fn.has("nvim-0.11") == 1 then
		it("delegates extmark URL resolution to native gx", function()
			attach({ "label" })
			api.nvim_buf_set_extmark(bufnr, api.nvim_create_namespace("markdown_test_url"), 0, 0, {
				end_col = 5,
				url = "mailto:hidden@example.org",
				hl_group = "Underlined",
			})
			gx()
			assert.are.same({ "mailto:hidden@example.org" }, opened)
		end)
	end
end)
