-- debug reload require to be removed
MDR = function(x)
	package.loaded[x] = nil
	return require(x)
end

local api = vim.api

local list = MDR("markdown.list")
local toc = MDR("markdown.toc")

local M = {}

local group = api.nvim_create_augroup("markdown.nvim", {})
local function handle_key_autocmd_opts(pattern)
	return {
		group = group,
		pattern = pattern,
		callback = function()
			vim.keymap.set({ "n", "i" }, "<M-l><M-o>", list.insert_list_item_below, { buffer = 0 })
			vim.keymap.set({ "n", "i" }, "<M-L><M-O>", list.insert_list_item_above, { buffer = 0 })
			vim.keymap.set({ "n", "i" }, "<M-l><M-n>", list.reset_list_numbering, { buffer = 0 })
		end
	}
end

function M.setup()
	api.nvim_create_user_command("MdInsertToc", toc.insert_toc, { force = true })

	api.nvim_clear_autocmds({ group = group })
	api.nvim_create_autocmd("BufEnter", handle_key_autocmd_opts({ "*.md" }))
	api.nvim_create_autocmd("FileType", handle_key_autocmd_opts("markdown"))
end

-- debug function
function TEST()
end

vim.keymap.set({ "n", "i" }, "<Leader><Leader>t", TEST, {})

return M
