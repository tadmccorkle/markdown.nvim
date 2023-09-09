local api = vim.api

local OpFunc = require("markdown.opfunc")
local config = require("markdown.config")
local list = require("markdown.list")
local toc = require("markdown.toc")
local inline = require("markdown.inline")

local M = {}

local group = api.nvim_create_augroup("markdown.nvim", {})

local function create_buf_user_cmd(name, cmd, range)
	api.nvim_buf_create_user_command(0, name, cmd, { force = true, range = range })
end

local function handle_key_autocmd_opts(pattern)
	return {
		group = group,
		pattern = pattern,
		callback = function()
			create_buf_user_cmd("MdInsertToc", toc.insert_toc, true)
			create_buf_user_cmd("MdListItemBelow", list.insert_list_item_below, false)
			create_buf_user_cmd("MdListItemAbove", list.insert_list_item_above, false)
			create_buf_user_cmd("MdResetListNumbering", list.reset_list_numbering, false)

			local surround_opts = config.opts.inline_surround
			if surround_opts.enable then
				vim.keymap.set("n", surround_opts.mappings.toggle, function()
					return OpFunc("markdown.inline", "toggle_emphasis")
				end, { buffer = 0, expr = true, silent = true })
				-- vim.keymap.set("n", "gss", function()
				-- 	return "^" .. tostring(vim.v.count1) .. "gsg_"
				-- end, { buffer = 0, expr = true, silent = true })
				vim.keymap.set("x", surround_opts.mappings.toggle,
					"<Esc>gv<Cmd>lua require'markdown.inline'.toggle_emphasis()<CR>",
					{ buffer = 0, silent = true })
				vim.keymap.set("n", surround_opts.mappings.delete, inline.delete_surrounding_emphasis,
					{ buffer = 0, silent = true })
				vim.keymap.set("n", surround_opts.mappings.change, inline.change_surrounding_emphasis,
					{ buffer = 0, silent = true })
			end
		end
	}
end

function M.setup()
	api.nvim_clear_autocmds({ group = group })
	api.nvim_create_autocmd("BufEnter", handle_key_autocmd_opts({ "*.md" }))
	api.nvim_create_autocmd("FileType", handle_key_autocmd_opts("markdown"))
end

-- debug function
function TEST()
	M.setup()
end

vim.keymap.set("n", "<Leader><Leader>t", TEST, {})

return M
