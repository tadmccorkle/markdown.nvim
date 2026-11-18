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

local MAX_LINE_NUM = 2147483647

describe("file line links", function()
	vim.cmd("runtime plugin/markdown.lua")
	local config = require("markdown.config")
	local link = require("markdown.link")
	local notify = require("markdown.notify")
	local dir, source, buffers, messages
	local get_parser, ui_open, info, ftplugins, fs_stat, cwd, cwd_scope

	before_each(function()
		config:reset()
		require("markdown").setup()
		fs_stat, cwd, cwd_scope = vim.uv.fs_stat, vim.fn.getcwd(), vim.fn.haslocaldir()
		-- Neovim 0.12's Lua ftplugin requires a Lua parser; this suite installs only Markdown.
		ftplugins = vim.g.did_load_ftplugin
		vim.cmd("filetype plugin off")
		buffers = {}
		for _, buf in ipairs(api.nvim_list_bufs()) do
			buffers[buf] = true
		end
		dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		dir = vim.uv.fs_realpath(dir)
		source = new_md_buf()
		api.nvim_buf_set_name(source, dir .. "/source.md")
		get_parser, ui_open, info = vim.treesitter.get_parser, vim.ui.open, notify.info
		messages = {}
		notify.info = function(message)
			table.insert(messages, message)
		end
	end)

	after_each(function()
		vim.treesitter.get_parser, vim.ui.open, notify.info = get_parser, ui_open, info
		vim.uv.fs_stat = fs_stat
		local cd = cwd_scope == 1 and "lcd" or (cwd_scope == 2 and "tcd" or "cd")
		vim.cmd[cd](vim.fn.fnameescape(cwd))
		config:reset()
		for _, buf in ipairs(api.nvim_list_bufs()) do
			if not buffers[buf] then
				api.nvim_buf_delete(buf, { force = true })
			end
		end
		vim.fn.delete(dir, "rf")
		if ftplugins then
			vim.cmd("filetype plugin on")
		end
	end)

	local function write_file(name, lines)
		vim.fn.writefile(lines or { "one", "two", "three", "four" }, dir .. "/" .. name)
	end

	local function follow(dest, opts)
		api.nvim_win_set_buf(0, source)
		set_buf(source, { "[target](" .. dest .. ")", "", "# L3", "# L3-L4" })
		api.nvim_win_set_cursor(0, { 1, 2 })
		link.follow(opts)
	end

	local function assert_target(name, line)
		assert.are.same(
			vim.fs.normalize(dir .. "/" .. name),
			vim.fs.normalize(api.nvim_buf_get_name(0))
		)
		assert.are.same({ line, 0 }, api.nvim_win_get_cursor(0))
	end

	local cases = {
		{ "L3", 3 },
		{ "L3-L4", 3 },
		{ "L3-4", 3 },
		{ "L0003", 3 },
		{ "L0", 1 },
		{ "L0-L0", 1 },
		{ "L99999", 4 },
		{ "L" .. string.rep("9", 400), 4 },
		{ "L4-L2", 4 },
		{ "L3-L99999", 3 },
		{ "L99999-100000", 4 },
	}
	for _, extension in ipairs({ "lua", "md" }) do
		for _, case in ipairs(cases) do
			it("follows " .. extension .. " fragment " .. case[1]:sub(1, 30), function()
				local name = "target." .. extension
				write_file(name)
				follow("./" .. name .. "#" .. case[1])
				assert_target(name, case[2])
				assert.are.same({}, messages)
			end)
		end
	end

	it("clamps into an empty file", function()
		write_file("empty.lua", {})
		follow("./empty.lua#L3")
		assert_target("empty.lua", 1)
	end)

	for _, fragment in ipairs({ "3", "l3", "L-3", "L+3", "L3x", "L3-L", "L3-", "L3:2" }) do
		it("does not interpret malformed fragment " .. fragment, function()
			write_file("target.lua")
			follow("./target.lua#" .. fragment)
			assert.are.same(source, api.nvim_get_current_buf())
			assert.are.same({ "path not found" }, messages)
			assert.are.same(0, vim.fn.filereadable(dir .. "/target.lua#" .. fragment))
		end)
	end

	it("preserves lowercase heading anchors in another Markdown file", function()
		write_file("target.md", { "# L3", "# L3-L4", "# L3", "text" })
		for _, case in ipairs({ { "l3", 1 }, { "l3-l4", 2 }, { "l3-1", 3 } }) do
			follow("./target.md#" .. case[1])
			assert_target("target.md", case[2])
		end
		follow("./target.md#L3")
		assert_target("target.md", 3)
		assert.are.same({}, messages)
	end)

	it("preserves missing-heading notifications", function()
		write_file("target.md")
		follow("./target.md#missing")
		assert.are.same({ "heading not found" }, messages)
	end)

	it("does not support fragment-only line jumps", function()
		follow("#L3")
		assert.are.same(source, api.nvim_get_current_buf())
		assert.are.same({ 1, 2 }, api.nvim_win_get_cursor(0))
		assert.are.same({ "heading not found" }, messages)
		follow("#l3")
		assert.are.same({ 3, 0 }, api.nvim_win_get_cursor(0))
	end)

	for _, suffix in ipairs({ "#L3", "#L3-L4", "#L3-4" }) do
		it("prefers a literal file ending in " .. suffix, function()
			write_file("target.lua")
			write_file("target.lua" .. suffix)
			follow("./target.lua" .. suffix)
			assert_target("target.lua" .. suffix, 1)
		end)
	end

	it("prefers a literal directory ending in a line anchor", function()
		write_file("target.lua")
		vim.fn.mkdir(dir .. "/target.lua#L3")
		follow("./target.lua#L3")
		assert.are.same(
			vim.fs.normalize(dir .. "/target.lua#L3"),
			vim.fs.normalize(api.nvim_buf_get_name(0))
		)
		assert.are.same({}, messages)
	end)

	it("does not navigate to lines in directories", function()
		vim.fn.mkdir(dir .. "/folder")
		follow("./folder#L3")
		assert.are.same(source, api.nvim_get_current_buf())
		assert.are.same({ "path not found" }, messages)
	end)

	it("does not create missing files", function()
		follow("./missing.lua#L3")
		assert.are.same(source, api.nvim_get_current_buf())
		assert.are.same(0, vim.fn.filereadable(dir .. "/missing.lua"))
		assert.are.same({ "path not found" }, messages)
	end)

	for _, failure in ipairs({ "error", "nil", "parse" }) do
		it("navigates to a line despite destination parser failure: " .. failure, function()
			write_file("target.md")
			vim.treesitter.get_parser = function(buf, ...)
				if buf == 0 and api.nvim_get_current_buf() ~= source then
					if failure == "error" then
						error("parser unavailable")
					elseif failure == "nil" then
						return nil
					end
					return {
						parse = function()
							error("parse failed")
						end,
					}
				end
				return get_parser(buf, ...)
			end
			follow("./target.md#L3")
			assert_target("target.md", 3)
			assert.are.same({}, messages)
		end)
	end

	it("strips line fragments for default-app opening but preserves literal paths", function()
		write_file("target.lua")
		local opened
		vim.ui.open = function(path)
			opened = path
		end
		follow("./target.lua#L3-L4", { use_default_app = true })
		assert.are.same(vim.fs.normalize(dir .. "/target.lua"), opened)
		assert.are.same(source, api.nvim_get_current_buf())
		write_file("target.lua#L3-L4")
		follow("./target.lua#L3-L4", { use_default_app = true })
		assert.are.same(vim.fs.normalize(dir .. "/target.lua#L3-L4"), opened)
	end)

	it("keeps Markdown navigation in the editor with default-app enabled", function()
		write_file("target.md")
		vim.ui.open = function()
			error("must not open externally")
		end
		follow("./target.md#L3", { use_default_app = true })
		assert_target("target.md", 3)
	end)

	it("leaves browser fragments untouched", function()
		local opened
		vim.ui.open = function(url)
			opened = url
		end
		follow("https://example.com/test.lua#L3-L4")
		assert.are.same("https://example.com/test.lua#L3-L4", opened)
		assert.are.same(source, api.nvim_get_current_buf())
	end)

	it("gives the hook the original destination and a working default callback", function()
		write_file("target.lua")
		local received
		require("markdown").setup({
			hooks = {
				follow_link = function(opts, default)
					received = opts
					default()
				end,
			},
		})
		follow("./target.lua#L3-4", { use_default_app = false })
		assert.are.same("./target.lua#L3-4", received.dest)
		assert.is_false(received.use_default_app)
		assert.are.same("path", received.kind)
		assert.are.same(source, received.bufnr)
		assert.are.same(vim.fs.normalize(dir .. "/target.lua"), received.path)
		assert.are.same("file", received.path_type)
		assert.is_false(received.is_markdown)
		assert.are.same("#L3-4", received.fragment)
		assert.are.same({ start_line = 3, end_line = 4 }, received.line_range)
		assert_target("target.lua", 3)
	end)

	local function context(dest, opts)
		local received
		require("markdown").setup({
			hooks = {
				follow_link = function(o)
					received = o
				end,
			},
		})
		follow(dest, opts)
		return received
	end

	for _, case in ipairs({
		{ "L3", 3, 3 },
		{ "L3-L7", 3, 7 },
		{ "L3-7", 3, 7 },
		{ "L0003", 3, 3 },
		{ "L7-L3", 7, 3 },
		{ "L0-L0", 0, 0 },
		{ "L" .. string.rep("9", 400), MAX_LINE_NUM, MAX_LINE_NUM },
		{ "L3-L" .. string.rep("9", 400), 3, MAX_LINE_NUM },
	}) do
		it("reports parsed range " .. case[1]:sub(1, 30), function()
			local o = context("./missing.md#" .. case[1])
			assert.are.same({ start_line = case[2], end_line = case[3] }, o.line_range)
			assert.are.same("#" .. case[1], o.fragment)
			assert.are.same("missing", o.path_type)
			assert.is_true(o.is_markdown)
			assert.are.same(vim.fs.normalize(dir .. "/missing.md"), o.path)
		end)
	end

	for _, dest in ipairs({
		"#L3",
		"#missing",
		"https://example.org/#L3",
		"www.example.org",
		"mailto:a@example.org",
		"file:///missing.md#L3",
	}) do
		it("omits path context for " .. dest, function()
			local o = context(dest)
			assert.are.same(dest:sub(1, 1) == "#" and "heading" or "external", o.kind)
			assert.are.same(source, o.bufnr)
			for _, key in ipairs({ "path", "fragment", "line_range", "path_type", "is_markdown" }) do
				assert.is_nil(o[key])
			end
		end)
	end

	it("preserves literal files and directories containing fragments", function()
		write_file("target.md#L3")
		vim.fn.mkdir(dir .. "/folder#L3")
		for _, case in ipairs({ { "target.md#L3", "file" }, { "folder#L3", "directory" } }) do
			local o = context("./" .. case[1])
			assert.are.same(vim.fs.normalize(dir .. "/" .. case[1]), o.path)
			assert.are.same(case[2], o.path_type)
			assert.is_nil(o.fragment)
			assert.is_nil(o.line_range)
		end
	end)

	it("only reports interpreted fragments", function()
		local o = context("./missing.txt#anchor")
		assert.are.same(vim.fs.normalize(dir .. "/missing.txt#anchor"), o.path)
		assert.is_nil(o.fragment)
		assert.is_nil(o.line_range)
		o = context("./missing.md#anchor")
		assert.are.same("#anchor", o.fragment)
		assert.is_nil(o.line_range)
		o = context("./missing.lua#L3x")
		assert.is_nil(o.fragment)
		assert.is_nil(o.line_range)
	end)

	it("resolves all relative path forms using the invocation context", function()
		vim.fn.mkdir(dir .. "/work", "p")
		vim.fn.mkdir(dir .. "/pages", "p")
		vim.cmd.lcd(vim.fn.fnameescape(dir .. "/work"))
		api.nvim_buf_set_name(source, dir .. "/pages/source.md")
		for _, case in ipairs({
			{ "missing.md", "/work/missing.md" },
			{ "/missing.md", "/work/missing.md" },
			{ "./missing.md", "/pages/missing.md" },
			{ "../missing.md", "/missing.md" },
			{ "../../missing.md", "/../missing.md" },
		}) do
			local o = context(case[1])
			assert.are.same(vim.fs.normalize(dir .. case[2]), o.path)
		end
	end)

	it("does not treat filesystem inspection errors as missing", function()
		vim.uv.fs_stat = function()
			return nil, "EACCES: permission denied", "EACCES"
		end
		assert.are.same("unknown", context("./missing.md").path_type)
	end)

	it("does not confuse unreadable files with missing paths", function()
		vim.uv.fs_stat = function()
			return { type = "file" }
		end
		assert.are.same("file", context("./missing.md").path_type)
	end)

	it("reports other filesystem objects", function()
		vim.uv.fs_stat = function()
			return { type = "fifo" }
		end
		assert.are.same("other", context("./pipe").path_type)
	end)

	it("uses the same resolved target despite hook mutations and cwd changes", function()
		write_file("target.lua")
		vim.cmd.lcd(vim.fn.fnameescape(dir))
		require("markdown").setup({
			hooks = {
				follow_link = function(o, fallback)
					o.path = dir .. "/wrong.lua"
					o.line_range.start_line = 1
					vim.cmd.lcd(vim.fn.fnameescape(cwd))
					fallback()
				end,
			},
		})
		follow("target.lua#L3-L4")
		assert_target("target.lua", 3)
	end)

	it("supports opening a missing Markdown page without writing it", function()
		require("markdown").setup({
			hooks = {
				follow_link = function(o, fallback)
					if o.kind == "path" and o.path_type == "missing" and o.is_markdown then
						vim.cmd.edit(vim.fn.fnameescape(o.path))
						return
					end
					fallback()
				end,
			},
		})
		follow("#missing")
		assert.are.same(source, api.nvim_get_current_buf())
		follow("./new%page.md#L3", { use_default_app = true })
		assert_target("new%page.md", 1)
		assert.are.same(0, vim.fn.filereadable(dir .. "/new%page.md"))
		assert.are.same(0, vim.fn.filereadable(dir .. "/new%page.md#L3"))
	end)
end)
