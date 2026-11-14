local api = vim.api

local M = {}

---@type table<integer, { cmds: table, maps: table }>
local cache = {}

local function create_cached_buf_usr_cmd(bufnr, name, cmd, opts)
	api.nvim_buf_create_user_command(bufnr, name, cmd, opts)
	table.insert(cache[bufnr].cmds, name)
end

local function del_cached_buf_usr_cmds(bufnr)
	for _, name in ipairs(cache[bufnr].cmds) do
		pcall(api.nvim_buf_del_user_command, bufnr, name)
	end
end

local function set_cached_keymap(mode, lhs, rhs, opts)
	if lhs then
		vim.keymap.set(mode, lhs, rhs, opts)
		table.insert(cache[opts.buffer].maps, { mode, lhs })
	end
end

local function del_cached_keymaps(bufnr)
	for _, map in ipairs(cache[bufnr].maps) do
		pcall(vim.keymap.del, map[1], map[2], { buffer = bufnr })
	end
end

local function setup_usr_cmds(bufnr)
	local cmd = require("markdown.cmd")
	local list = require("markdown.list")

	-- stylua: ignore start

	-- toc
	create_cached_buf_usr_cmd(
		bufnr,
		"MDInsertToc",
		cmd.insert_toc,
		{
			force = true,
			range = true,
			nargs = "*",
		})
	create_cached_buf_usr_cmd(
		bufnr,
		"MDToc",
		cmd.show_toc,
		{
			force = true,
			nargs = "*",
		})
	create_cached_buf_usr_cmd(
		bufnr,
		"MDTocAll",
		cmd.show_toc_all,
		{
			force = true,
			nargs = "*",
		})

	-- list
	create_cached_buf_usr_cmd(
		bufnr,
		"MDListItemBelow",
		list.insert_list_item_below,
		{
			force = true,
		})
	create_cached_buf_usr_cmd(
		bufnr,
		"MDListItemAbove",
		list.insert_list_item_above,
		{
			force = true,
		})
	create_cached_buf_usr_cmd(
		bufnr,
		"MDResetListNumbering",
		cmd.reset_list_numbering,
		{
			force = true,
			range = true,
		})
	create_cached_buf_usr_cmd(
		bufnr,
		"MDTaskToggle",
		cmd.toggle_task,
		{
			force = true,
			range = true,
		})

	-- stylua: ignore end
end

local function setup_usr_keymaps(cfg, bufnr)
	if not cfg.mappings then
		return
	end

	-- stylua: ignore start
	set_cached_keymap(
		"n",
		cfg.mappings.inline_surround_toggle,
		"<Plug>(markdown_toggle_emphasis)",
		{
			buffer = bufnr,
			desc = "Toggle emphasis around a motion",
		})
	set_cached_keymap(
		"n",
		cfg.mappings.inline_surround_toggle_line,
		"<Plug>(markdown_toggle_emphasis_line)",
		{
			buffer = bufnr,
			desc = "Toggle emphasis around a line",
		})
	set_cached_keymap(
		"x",
		cfg.mappings.inline_surround_toggle,
		"<Plug>(markdown_toggle_emphasis_visual)",
		{
			buffer = bufnr,
			desc = "Toggle emphasis around a visual selection",
		})
	set_cached_keymap(
		"n",
		cfg.mappings.inline_surround_delete,
		"<Plug>(markdown_delete_emphasis)",
		{
			buffer = bufnr,
			desc = "Delete emphasis around the cursor",
		})
	set_cached_keymap(
		"n",
		cfg.mappings.inline_surround_change,
		"<Plug>(markdown_change_emphasis)",
		{
			buffer = bufnr,
			desc = "Change emphasis around the cursor",
		})
	set_cached_keymap(
		"n",
		cfg.mappings.link_add,
		"<Plug>(markdown_add_link)",
		{
			buffer = bufnr,
			desc = "Add link around a motion",
		})
	set_cached_keymap(
		"x",
		cfg.mappings.link_add,
		"<Plug>(markdown_add_link_visual)",
		{
			buffer = bufnr,
			desc = "Add link around a visual selection",
		})
	if cfg.mappings.link_follow then
		require("markdown.link_mapping").capture(bufnr, cfg.mappings.link_follow)
		vim.keymap.set(
			"n",
			cfg.mappings.link_follow,
			"<Plug>(markdown_follow_link)",
			{
				buffer = bufnr,
				desc = "Follow link under the cursor",
			})
	end
	set_cached_keymap(
		"n",
		cfg.mappings.go_curr_heading,
		"<Plug>(markdown_go_current_heading)",
		{
			buffer = bufnr,
			desc = "Set cursor to current section heading",
		})
	set_cached_keymap(
		"n",
		cfg.mappings.go_parent_heading,
		"<Plug>(markdown_go_parent_heading)",
		{
			buffer = bufnr,
			desc = "Set cursor to parent section heading",
		})
	set_cached_keymap(
		"n",
		cfg.mappings.go_next_heading,
		"<Plug>(markdown_go_next_heading)",
		{
			buffer = bufnr,
			desc = "Set cursor to next section heading",
		})
	set_cached_keymap(
		"n",
		cfg.mappings.go_prev_heading,
		"<Plug>(markdown_go_prev_heading)",
		{
			buffer = bufnr,
			desc = "Set cursor to previous section heading",
		})
	-- stylua: ignore end
end

local function check_deps()
	-- stylua: ignore start
	local has_markdown = #(api.nvim_get_runtime_file("parser/markdown.so", true)) > 0
	local has_markdown_inline = #(api.nvim_get_runtime_file("parser/markdown_inline.so", true)) > 0
	if not (has_markdown and has_markdown_inline) then
		local err = "Missing required tree-sitter parser:"
		if not has_markdown then err = err .. " 'markdown'" end
		if not has_markdown_inline then err = err .. " 'markdown_inline'" end
		require("markdown.notify").error(err)
		return false
	end
	return true
	-- stylua: ignore end
end

---@param bufnr integer
local function is_markdown(bufnr)
	local ft = api.nvim_get_option_value("filetype", { buf = bufnr })
	return vim.tbl_contains(vim.treesitter.language.get_filetypes("markdown"), ft)
end

local group = api.nvim_create_augroup("markdown.nvim", {})
local autocmd_buf_key = vim.fn.has("nvim-0.13") == 1 and "buf" or "buffer"

---@param bufnr integer
local function forget_buffer(bufnr)
	cache[bufnr] = nil
	require("markdown.link_mapping").forget(bufnr)
end

---@param bufnr integer
function M._on_detach(bufnr)
	if cache[bufnr] == nil then
		return
	end

	if api.nvim_buf_is_valid(bufnr) then
		del_cached_buf_usr_cmds(bufnr)
		del_cached_keymaps(bufnr)
		cache[bufnr] = nil

		vim.b[bufnr].markdown_nvim_attached = nil

		require("markdown.link_mapping").restore(bufnr)
	else
		forget_buffer(bufnr)
	end
end

---@param bufnr integer
local function on_attach(bufnr)
	if cache[bufnr] ~= nil then
		if vim.b[bufnr].markdown_nvim_attached == 1 then
			return
		end

		-- Neovim cleared this recoverable buffer's registrations (:bdelete).
		forget_buffer(bufnr)
	end

	cache[bufnr] = { cmds = {}, maps = {} }

	local buf_vars = vim.b[bufnr]

	buf_vars.markdown_nvim_attached = 1

	local undo = "lua require('markdown')._on_detach(vim.api.nvim_get_current_buf())"
	local previous = buf_vars.undo_ftplugin or ""
	if not previous:find(undo, 1, true) then
		buf_vars.undo_ftplugin = previous == "" and undo or previous .. "|" .. undo
	end

	-- BufWipeout can accompany renames. Only forget Lua state after the buffer
	-- operation finishes and its handle is actually invalid.
	api.nvim_clear_autocmds({ group = group, event = "BufWipeout", [autocmd_buf_key] = bufnr })
	api.nvim_create_autocmd("BufWipeout", {
		group = group,
		[autocmd_buf_key] = bufnr,
		callback = function(opts)
			vim.schedule(function()
				if not api.nvim_buf_is_valid(opts.buf) then
					forget_buffer(opts.buf)
				end
			end)
		end,
	})

	local cfg = require("markdown.config"):get()

	setup_usr_cmds(bufnr)
	setup_usr_keymaps(cfg, bufnr)

	if cfg.link.paste.enable then
		require("markdown.link").register_paste_handler()
	end

	if cfg.on_attach ~= nil then
		cfg.on_attach(bufnr)
	end
end

--- Setup with user options.
---@param cfg? MarkdownConfig
function M.setup(cfg)
	if not check_deps() then
		return
	end

	require("markdown.config"):setup(cfg)

	api.nvim_clear_autocmds({ group = group, event = "FileType" })
	api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = vim.treesitter.language.get_filetypes("markdown"),
		callback = function(opts)
			on_attach(opts.buf)
		end,
	})

	-- Include existing Markdown buffers in case we were lazy-loaded.
	for _, bufnr in ipairs(api.nvim_list_bufs()) do
		if api.nvim_buf_is_loaded(bufnr) and is_markdown(bufnr) then
			on_attach(bufnr)
		end
	end
end

--- Initializes the plugin as treesitter module.
function M.define_nvim_ts_module()
	require("nvim-treesitter").define_modules({
		markdown = {
			attach = function(bufnr, _)
				if not check_deps() then
					return
				end

				local mod_cfgs = require("nvim-treesitter.configs")
				local mod_cfg = mod_cfgs.get_module("markdown")
				if mod_cfg ~= nil then
					require("markdown.config"):setup(mod_cfg --[[@as MarkdownConfig]])
				end

				on_attach(bufnr)
			end,
			detach = M._on_detach,
			is_supported = function(lang)
				return lang == "markdown"
			end,
		},
	})
end

return M
