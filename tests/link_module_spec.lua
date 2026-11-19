local api = vim.api
local state = require("luassert.state")
local stub = require("luassert.stub")

describe("link mapping module lifecycle", function()
	local snapshot, treesitter, configs

	before_each(function()
		snapshot = state.snapshot()
		treesitter = package.loaded["nvim-treesitter"]
		configs = package.loaded["nvim-treesitter.configs"]
	end)

	after_each(function()
		snapshot:revert()
		package.loaded["nvim-treesitter"] = treesitter
		package.loaded["nvim-treesitter.configs"] = configs
	end)

	it("restores previous mappings on detach and preserves fallback on reattach", function()
		local module
		local ts, ts_configs = {}, {}
		stub(ts, "define_modules", function(modules)
			module = modules.markdown
		end)
		stub(ts_configs, "get_module")
		-- Replace module tables too: the modern treesitter integration has no configs module.
		package.loaded["nvim-treesitter"] = ts
		package.loaded["nvim-treesitter.configs"] = ts_configs
		local bufnr = api.nvim_create_buf(true, true)
		api.nvim_win_set_buf(0, bufnr)
		api.nvim_buf_set_lines(bufnr, 0, -1, false, { "plain text" })
		local calls = 0
		vim.keymap.set("n", "gx", function()
			calls = calls + 1
		end, { buffer = bufnr })
		local previous = vim.fn.maparg("gx", "n", false, true)

		local ok, err = pcall(function()
			vim.cmd("runtime plugin/markdown.lua")
			require("markdown.config"):reset()
			require("markdown").define_nvim_ts_module()
			for _ = 1, 2 do
				module.attach(bufnr, "markdown")
				module.attach(bufnr, "markdown")

				vim.cmd("normal gx")
				api.nvim_feedkeys("", "x", false)

				module.detach(bufnr)
				vim.cmd(vim.b.undo_ftplugin)

				assert.are.same(previous, vim.fn.maparg("gx", "n", false, true))
				assert.is_nil(vim.b[bufnr].markdown_nvim_attached)
			end
			assert.are.same(2, calls)
		end)

		api.nvim_buf_delete(bufnr, { force = true })
		assert.is_true(ok, err)
	end)
end)
