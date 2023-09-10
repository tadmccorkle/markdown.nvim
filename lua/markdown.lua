local api = vim.api
local K = vim.keymap.set

local OpFunc = require("markdown.opfunc")
local config = require("markdown.config")
local list = require("markdown.list")
local toc = require("markdown.toc")
local inline = require("markdown.inline")

local M = {}

local group = api.nvim_create_augroup("markdown.nvim", {})

local function buf_usr_cmd(name, cmd, range)
	api.nvim_buf_create_user_command(0, name, cmd, { force = true, range = range })
end

local function setup_usr_cmds()
	buf_usr_cmd("MDInsertToc", toc.insert_toc, true)
	buf_usr_cmd("MDListItemBelow", list.insert_list_item_below, false)
	buf_usr_cmd("MDListItemAbove", list.insert_list_item_above, false)
	buf_usr_cmd("MDResetListNumbering", list.reset_list_numbering, false)
	buf_usr_cmd("MDTaskToggle", list.toggle_task, true)
end

local function setup_keymaps()
	local surround_opts = config.opts.inline_surround
	if surround_opts.enable then
		K(
			"n",
			"<Plug>(markdown_toggle_emphasis)",
			function()
				return OpFunc("markdown.inline", "toggle_emphasis")
			end, {
				buffer = 0,
				expr = true,
				silent = true,
				desc = "Toggle emphasis around a motion",
			}
		)
		K(
			"n",
			"<Plug>(markdown_toggle_emphasis_current_line)",
			function()
				return "^" .. tostring(vim.v.count1) .. "<Plug>(markdown_toggle_emphasis)g_"
			end, {
				buffer = 0,
				expr = true,
				silent = true,
				desc = "Toggle emphasis around the current line",
			}
		)
		K(
			"x",
			"<Plug>(markdown_toggle_emphasis_visual)",
			"<Esc>gv<Cmd>lua require'markdown.inline'.toggle_emphasis()<CR>", {
				buffer = 0,
				silent = true,
				desc = "Toggle emphasis around a visual selection",
			}
		)
		K(
			"n",
			"<Plug>(markdown_delete_emphasis)",
			inline.delete_surrounding_emphasis, {
				buffer = 0,
				silent = true,
				desc = "Delete emphasis around the cursor",
			}
		)
		K(
			"n",
			"<Plug>(markdown_change_emphasis)",
			inline.change_surrounding_emphasis, {
				buffer = 0,
				silent = true,
				desc = "Change emphasis around the cursor",
			}
		)

		K("n", surround_opts.mappings.toggle, "<Plug>(markdown_toggle_emphasis)", {
			buffer = 0,
			desc = "Toggle emphasis around a motion",
		})
		K("n", surround_opts.mappings.toggle_line, "<Plug>(markdown_toggle_emphasis_current_line)", {
			buffer = 0,
			desc = "Toggle emphasis around the current line",
		})
		K("x", surround_opts.mappings.toggle, "<Plug>(markdown_toggle_emphasis_visual)", {
			buffer = 0,
			desc = "Toggle emphasis around a visual selection",
		})
		K("n", surround_opts.mappings.delete, "<Plug>(markdown_delete_emphasis)", {
			buffer = 0,
			desc = "Delete emphasis around the cursor",
		})
		K("n", surround_opts.mappings.change, "<Plug>(markdown_change_emphasis)", {
			buffer = 0,
			desc = "Change emphasis around the cursor",
		})
	end
end

local function on_attach_cb()
	setup_usr_cmds()
	setup_keymaps()

	if config.on_attach ~= nil then
		config.on_attach()
	end
end

--- Setup with user options.
---@param cfg? table
---@param on_attach fun()
function M.setup(cfg, on_attach)
	config.setup(cfg, on_attach)

	api.nvim_clear_autocmds({ group = group })
	api.nvim_create_autocmd("BufEnter", {
		group = group,
		pattern = { "*.md" },
		callback = on_attach_cb,
	})
	api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "markdown",
		callback = on_attach_cb,
	})
end

return M
