local api = vim.api
local markdown = require("markdown")
local config = require("markdown.config")
local mapping = require("markdown.link_mapping")

local function tick()
	local done = false
	vim.schedule(function()
		done = true
	end)
	vim.wait(1000, function()
		return done
	end, 50)
	assert.is_true(done)
end

local function gx()
	vim.cmd("normal gx")
	api.nvim_feedkeys("", "x", false)
end

local function get_map(lhs)
	return vim.fn.maparg(lhs, "n", false, true)
end

local function handlers(buf)
	return api.nvim_get_autocmds({ group = "markdown.nvim", event = "BufWipeout", buffer = buf })
end

describe("plugin lifecycle", function()
	local buffers, dir, attached, forgotten, restored, followed, forget, restore

	vim.cmd("runtime plugin/markdown.lua")
	vim.cmd("filetype plugin on")

	before_each(function()
		buffers = {}
		for _, buf in ipairs(api.nvim_list_bufs()) do
			buffers[buf] = true
		end
		dir = vim.fn.tempname()
		vim.fn.mkdir(dir, "p")
		attached, forgotten, restored, followed = {}, {}, {}, 0
		forget, restore = mapping.forget, mapping.restore
		mapping.forget = function(buf)
			forgotten[buf] = true
			forget(buf)
		end
		mapping.restore = function(buf)
			restored[buf] = true
			restore(buf)
		end
		config:reset()
		markdown.setup({
			on_attach = function(buf)
				assert.are.same(buf, api.nvim_get_current_buf())
				attached[buf] = (attached[buf] or 0) + 1
			end,
		})
	end)

	after_each(function()
		mapping.forget, mapping.restore = forget, restore
		for _, buf in ipairs(api.nvim_list_bufs()) do
			if not buffers[buf] then
				api.nvim_buf_delete(buf, { force = true })
			end
		end
		tick()
		vim.fn.delete(dir, "rf")
		config:reset()
	end)

	local function fallback(buf)
		vim.keymap.set("n", "gx", function()
			followed = followed + 1
		end, { buffer = buf })
	end

	local function new_buf(name, before_attach)
		local buf = api.nvim_create_buf(true, false)
		api.nvim_win_set_buf(0, buf)
		api.nvim_buf_set_name(buf, dir .. "/" .. (name or "source.md"))
		api.nvim_buf_set_lines(buf, 0, -1, false, { "plain text" })
		if before_attach then
			before_attach(buf)
		end
		vim.bo[buf].filetype = "markdown"
		return buf
	end

	it("uses ftplugin undo to remove mappings and restore the previous follow mapping", function()
		local previous
		local buf = new_buf(nil, function(b)
			fallback(b)
			vim.keymap.set("n", "gl", "j", { buffer = b })
			previous = get_map("gx")
		end)
		assert.are.same(1, attached[buf])
		assert.is_not_nil(api.nvim_buf_get_commands(buf, {}).MDToc)
		gx()
		assert.are.same(1, followed)

		vim.bo[buf].filetype = "text"
		assert.is_nil(vim.b[buf].markdown_nvim_attached)
		assert.is_nil(api.nvim_buf_get_commands(buf, {}).MDToc)
		assert.are.same(previous, get_map("gx"))
		-- Ordinary overwritten buffer-local mappings have no restoration stack.
		assert.are.same({}, get_map("gl"))
		assert.are.same({}, get_map("<Plug>(markdown_previous_follow_link)"))
		gx()
		assert.are.same(2, followed)

		vim.bo[buf].filetype = "markdown"
		assert.are.same(2, attached[buf])
		assert.are.same("<Plug>(markdown_follow_link)", get_map("gx").rhs)
		gx()
		assert.are.same(3, followed)
	end)

	it("exposes the native global follow mapping after ftplugin undo", function()
		local previous = get_map("gx")
		local buf = new_buf()
		assert.are.same(1, get_map("gx").buffer)
		vim.bo[buf].filetype = "text"
		assert.are.same(previous, get_map("gx"))
		assert.are.same(0, get_map("gx").buffer)
	end)

	it("preserves a follow mapping replaced after attachment", function()
		local buf = new_buf()
		fallback(buf)
		local replacement = get_map("gx")
		vim.bo[buf].filetype = "text"
		assert.are.same(replacement, get_map("gx"))
		gx()
		assert.are.same(1, followed)
		vim.bo[buf].filetype = "markdown"
		gx()
		assert.are.same(2, followed)
	end)

	it("preserves attachments and destruction handlers across repeated setup", function()
		local first = new_buf("first.md")
		local second = new_buf("second.md")
		-- Exercise attachment to a non-current buffer as well.
		vim.bo[first].filetype = "text"
		vim.bo[first].filetype = "markdown"
		assert.are.same(second, api.nvim_get_current_buf())
		local ids = { [first] = handlers(first)[1].id, [second] = handlers(second)[1].id }
		markdown.setup()
		markdown.setup()
		assert.are.same(2, attached[first])
		assert.are.same(1, attached[second])
		for _, buf in ipairs({ first, second }) do
			assert.are.same(1, #handlers(buf))
			assert.are.same(ids[buf], handlers(buf)[1].id)
			api.nvim_buf_delete(buf, { force = true })
		end
		tick()
		assert.is_true(forgotten[first])
		assert.is_true(forgotten[second])
	end)

	it("keeps one destruction handler per buffer after reattachment", function()
		local buf = new_buf()
		assert.are.same(1, #handlers(buf))
		for _ = 1, 3 do
			vim.bo[buf].filetype = "text"
			vim.bo[buf].filetype = "markdown"
			assert.are.same(1, #handlers(buf))
			markdown._on_detach(buf)
			markdown.setup()
			assert.are.same(1, #handlers(buf))
		end
		api.nvim_buf_delete(buf, { force = true })
		tick()
		assert.is_true(forgotten[buf])
	end)

	for _, operation in ipairs({ "file", "saveas", "api", "BufWipeout" }) do
		it("preserves attachment and fallback across " .. operation, function()
			local buf = new_buf(nil, fallback)
			local target = dir .. "/renamed.md"
			if operation == "api" then
				api.nvim_buf_set_name(buf, target)
			elseif operation == "BufWipeout" then
				api.nvim_exec_autocmds("BufWipeout", { buffer = buf })
			else
				vim.cmd[operation](target)
			end
			tick()
			assert.is_true(api.nvim_buf_is_valid(buf))
			assert.are.same(buf, api.nvim_get_current_buf())
			assert.is_nil(forgotten[buf])
			assert.is_nil(restored[buf])
			markdown.setup()
			assert.are.same(1, attached[buf])
			gx()
			assert.are.same(1, followed)
		end)
	end

	for _, operation in ipairs({ "bunload", "bdelete" }) do
		it("retains bookkeeping for a valid buffer after " .. operation, function()
			local buf = new_buf()
			vim.cmd(operation .. "! " .. buf)
			tick()
			assert.is_true(api.nvim_buf_is_valid(buf))
			assert.is_nil(forgotten[buf])
			assert.is_nil(restored[buf])
			vim.cmd("buffer " .. buf)
			assert.are.same(1, vim.b[buf].markdown_nvim_attached)
			assert.are.same("<Plug>(markdown_follow_link)", get_map("gx").rhs)
			assert.is_not_nil(api.nvim_buf_get_commands(buf, {}).MDToc)
		end)
	end

	it("only forgets internal state after confirming actual destruction", function()
		local buf = new_buf()
		api.nvim_buf_delete(buf, { force = true })
		assert.is_false(api.nvim_buf_is_valid(buf))
		assert.is_nil(forgotten[buf])
		tick()
		assert.is_true(forgotten[buf])
		assert.is_nil(restored[buf])
	end)

	it("preserves existing ftplugin undo and does not append duplicate cleanup", function()
		local buf = new_buf()
		markdown._on_detach(buf)
		vim.b.undo_ftplugin = "let b:markdown_lifecycle_test = 1"
		markdown.setup()
		local undo = vim.b.undo_ftplugin
		assert.is_truthy(undo:find("let b:markdown_lifecycle_test = 1|", 1, true))
		markdown.setup()
		assert.are.same(undo, vim.b.undo_ftplugin)
		markdown._on_detach(buf)
		markdown.setup()
		assert.are.same(undo, vim.b.undo_ftplugin)
		vim.bo[buf].filetype = "text"
		assert.are.same(1, vim.b.markdown_lifecycle_test)
		assert.is_nil(vim.b.markdown_nvim_attached)
		markdown._on_detach(buf)
	end)
end)
