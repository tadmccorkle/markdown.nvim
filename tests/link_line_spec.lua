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

describe("file line links", function()
	vim.cmd("runtime plugin/markdown.lua")
	local config = require("markdown.config")
	local link = require("markdown.link")
	local notify = require("markdown.notify")
	local dir, source, buffers, messages
	local get_parser, ui_open, info, ftplugins

	before_each(function()
		config:reset()
		require("markdown").setup()
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
		assert.are.same({ dest = "./target.lua#L3-4", use_default_app = false }, received)
		assert_target("target.lua", 3)
	end)
end)
