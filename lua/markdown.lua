local api = vim.api

local OpFunc = require("markdown.opfunc")
local config = require("markdown.config")
local list = require("markdown.list")
local toc = require("markdown.toc")
local inline = require("markdown.inline")

local M = {}

local function set_keymaps()
	vim.keymap.set(
		"n",
		"<Plug>(markdown_toggle_emphasis)",
		function()
			return OpFunc("markdown.inline", "toggle_emphasis")
		end,
		{
			expr = true,
			silent = true,
			desc = "Toggle emphasis around a motion",
		})
	vim.keymap.set(
		"n",
		"<Plug>(markdown_toggle_emphasis_current_line)",
		function()
			return "^" .. tostring(vim.v.count1) .. "<Plug>(markdown_toggle_emphasis)g_"
		end,
		{
			expr = true,
			silent = true,
			desc = "Toggle emphasis around the current line",
		})
	vim.keymap.set(
		"x",
		"<Plug>(markdown_toggle_emphasis_visual)",
		"<Esc>gv<Cmd>lua require'markdown.inline'.toggle_emphasis()<CR>",
		{
			silent = true,
			desc = "Toggle emphasis around a visual selection",
		})
	vim.keymap.set(
		"n",
		"<Plug>(markdown_delete_emphasis)",
		inline.delete_surrounding_emphasis,
		{
			silent = true,
			desc = "Delete emphasis around the cursor",
		})
	vim.keymap.set(
		"n",
		"<Plug>(markdown_change_emphasis)",
		inline.change_surrounding_emphasis,
		{
			silent = true,
			desc = "Change emphasis around the cursor",
		})
end

---@type table<integer, { cmds: table, maps: table }>
local cache

local function create_cached_buf_usr_cmd(bufnr, name, cmd, range)
	api.nvim_buf_create_user_command(bufnr, name, cmd, { force = true, range = range })
	if cache ~= nil then table.insert(cache[bufnr].cmds, name) end
end

local function del_cached_buf_usr_cmds(bufnr)
	for i = 1, #cache[bufnr].cmds, 1 do
		api.nvim_buf_del_user_command(bufnr, cache[bufnr].cmds[i])
	end
end

local function set_cached_keymap(mode, lhs, rhs, opts)
	vim.keymap.set(mode, lhs, rhs, opts)
	if cache ~= nil then table.insert(cache[opts.buffer].maps, { mode, rhs }) end
end

local function del_cached_keymaps(bufnr)
	for i = 1, #cache[bufnr].maps, 1 do
		local map = cache[bufnr].maps[i]
		local opts = bufnr ~= nil and { buffer = bufnr } or nil
		vim.keymap.del(map[1], map[2], opts)
	end
end

local function setup_usr_cmds(bufnr)
	create_cached_buf_usr_cmd(bufnr, "MDInsertToc", toc.insert_toc, true)
	create_cached_buf_usr_cmd(bufnr, "MDListItemBelow", list.insert_list_item_below, false)
	create_cached_buf_usr_cmd(bufnr, "MDListItemAbove", list.insert_list_item_above, false)
	create_cached_buf_usr_cmd(bufnr, "MDResetListNumbering", list.reset_list_numbering, false)
	create_cached_buf_usr_cmd(bufnr, "MDTaskToggle", list.toggle_task, true)
end

local function setup_usr_keymaps(cfg, bufnr)
	if cfg.inline_surround.mappings.enable then
		set_cached_keymap(
			"n",
			cfg.inline_surround.mappings.toggle,
			"<Plug>(markdown_toggle_emphasis)",
			{
				buffer = bufnr,
				desc = "Toggle emphasis around a motion",
			})
		set_cached_keymap(
			"n",
			cfg.inline_surround.mappings.toggle_line,
			"<Plug>(markdown_toggle_emphasis_current_line)",
			{
				buffer = bufnr,
				desc = "Toggle emphasis around the current line",
			})
		set_cached_keymap(
			"x",
			cfg.inline_surround.mappings.toggle,
			"<Plug>(markdown_toggle_emphasis_visual)",
			{
				buffer = bufnr,
				desc = "Toggle emphasis around a visual selection",
			})
		set_cached_keymap(
			"n",
			cfg.inline_surround.mappings.delete,
			"<Plug>(markdown_delete_emphasis)",
			{
				buffer = bufnr,
				desc = "Delete emphasis around the cursor",
			})
		set_cached_keymap(
			"n",
			cfg.inline_surround.mappings.change,
			"<Plug>(markdown_change_emphasis)",
			{
				buffer = bufnr,
				desc = "Change emphasis around the cursor",
			})
	end
end

local function on_attach(bufnr)
	local cfg = config:get()

	setup_usr_cmds(bufnr)
	setup_usr_keymaps(cfg, bufnr)

	if cfg.on_attach ~= nil then
		cfg.on_attach(bufnr)
	end
end

local group = api.nvim_create_augroup("markdown.nvim", {})

---@type table<integer, boolean>
local attached = {}

local function on_attach_cb(opts)
	if not attached[opts.buf] then
		on_attach(opts.buf)
		attached[opts.buf] = true
	end
end

--- Setup with user options.
---@param cfg? MarkdownConfig
function M.setup(cfg)
	cfg = config:setup(cfg)

	api.nvim_clear_autocmds({ group = group })
	api.nvim_create_autocmd("BufEnter", {
		group = group,
		pattern = cfg.file_patterns,
		callback = on_attach_cb,
	})
	api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = cfg.file_types,
		callback = on_attach_cb,
	})
end

--- Sets plugin keymaps and attempts to initialize plugin as treesitter module.
function M.init()
	set_keymaps()

	local ok, nvim_ts = pcall(require, "nvim-treesitter")
	if not ok then return end

	nvim_ts.define_modules({
		markdown = {
			attach = function(bufnr, _)
				local mod_cfgs = require("nvim-treesitter.configs")
				local has_cfg, mod_cfg = pcall(mod_cfgs.get_module, "markdown")
				if has_cfg then
					config:setup(mod_cfg --[[@as MarkdownConfig]])
				end

				if cache == nil then
					cache = {}
				end
				cache[bufnr] = { cmds = {}, maps = {} }

				on_attach(bufnr)
			end,
			detach = function(bufnr)
				del_cached_buf_usr_cmds(bufnr)
				del_cached_keymaps(bufnr)
				cache[bufnr] = nil
			end,
			is_supported = function(lang)
				return lang == "markdown"
			end,
		}
	})
end

return M
