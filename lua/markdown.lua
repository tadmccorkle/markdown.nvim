local api = vim.api

local M = {}

---@type table<integer, { cmds: table, maps: table }>
local cache

local function create_cached_buf_usr_cmd(bufnr, name, cmd, opts)
	api.nvim_buf_create_user_command(bufnr, name, cmd, opts)
	if cache ~= nil then
		table.insert(cache[bufnr].cmds, name)
	end
end

local function del_cached_buf_usr_cmds(bufnr)
	for i = 1, #cache[bufnr].cmds, 1 do
		api.nvim_buf_del_user_command(bufnr, cache[bufnr].cmds[i])
	end
end

local function set_cached_keymap(mode, lhs, rhs, opts)
	if not lhs then return end

	vim.keymap.set(mode, lhs, rhs, opts)
	if cache ~= nil then
		table.insert(cache[opts.buffer].maps, { mode, rhs })
	end
end

local function del_cached_keymaps(bufnr)
	local opts = bufnr ~= nil and { buffer = bufnr } or nil
	for i = 1, #cache[bufnr].maps, 1 do
		local map = cache[bufnr].maps[i]
		vim.keymap.del(map[1], map[2], opts)
	end
end

local function setup_usr_cmds(bufnr)
	local cmd = require("markdown.cmd")

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

	local list = require("markdown.list")
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
end

local function setup_usr_keymaps(cfg, bufnr)
	if cfg.mappings then
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
		set_cached_keymap(
			"n",
			cfg.mappings.link_follow,
			"<Plug>(markdown_follow_link)",
			{
				buffer = bufnr,
				desc = "Follow link under the cursor",
			})
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
	end
end

local function check_deps()
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
end

local function on_attach(bufnr)
	api.nvim_buf_set_var(bufnr, "markdown_nvim_attached", 1)

	local cfg = require("markdown.config"):get()

	setup_usr_cmds(bufnr)
	setup_usr_keymaps(cfg, bufnr)

	if cfg.link.paste.enable then
		local link = require("markdown.link")
		link.register_paste_handler()
	end

	if cfg.on_attach ~= nil then
		cfg.on_attach(bufnr)
	end
end

local group = api.nvim_create_augroup("markdown.nvim", {})

--- Setup with user options.
---@param cfg? MarkdownConfig
function M.setup(cfg)
	if not check_deps() then
		return
	end

	require("markdown.config"):setup(cfg)

	api.nvim_clear_autocmds({ group = group })
	api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = vim.treesitter.language.get_filetypes("markdown"),
		callback = function(opts)
			---@diagnostic disable-next-line: undefined-field
			if vim.b.markdown_nvim_attached ~= 1 then
				on_attach(opts.buf)
			end
		end,
	})

	-- exec autocmd for existing buffers in case we were lazy-loaded
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			vim.api.nvim_exec_autocmds("FileType", { group = group, buffer = bufnr })
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
		},
	})
end

return M
