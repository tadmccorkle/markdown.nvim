--- Functions to handle user command argument processing.
---
---@see nvim_create_user_command
local M = {}

function M.insert_toc(opts)
	local o = {}

	if #opts.fargs > 0 then
		local args
		if vim.startswith(opts.args, "/") then
			args = vim.split(opts.args, "/", { plain = true, trimempty = true })
		else
			args = opts.fargs
		end

		if #args > 0 then
			o.max_level = tonumber(args[1])
			if o.max_level ~= nil then
				if #args > 1 then
					o.markers = { unpack(args, 2) }
				end
			else
				o.markers = args
			end
		end
	else
		o.markers = require("markdown.config"):get().toc.markers
	end

	if o.markers == nil or #o.markers == 0 then
		o.markers = { "-" }
	end

	local s, e = require("markdown.util").get_user_command_range(opts)
	o.start_row = s
	if opts.range ~= 0 then
		o.end_row = e
	end

	require("markdown.toc").insert_toc(o)
end

local function show_toc(opts, omit_flagged)
	local o = {
		omit_flagged = omit_flagged,
		indent_subsections = true,
	}
	if #opts.fargs > 0 then
		o.max_level = tonumber(opts.fargs[1])
	end

	require("markdown.toc").set_loclist_toc(o)

	vim.cmd({
		cmd = "lopen",
		count = #opts.fargs > 1 and tonumber(opts.fargs[2]) or nil,
		mods = opts.smods,
	})

	vim.api.nvim_set_option_value("modifiable", true, { scope = "local" })
	for i, item in ipairs(vim.fn.getloclist(0)) do
		vim.api.nvim_buf_set_lines(0, i - 1, i, true, { item.text })
	end
	vim.api.nvim_set_option_value("modified", false, { scope = "local" })
	vim.api.nvim_set_option_value("modifiable", false, { scope = "local" })
end

function M.show_toc(opts)
	show_toc(opts, true)
end

function M.show_toc_all(opts)
	show_toc(opts, false)
end

function M.reset_list_numbering(opts)
	local s, e
	if opts.range ~= 0 then
		s, e = require("markdown.util").get_user_command_range(opts)
	else
		s, e = 0, -1
	end
	require("markdown.list").reset_list_numbering(s, e)
end

function M.toggle_task(opts)
	local s, e = require("markdown.util").get_user_command_range(opts)
	require("markdown.list").toggle_task(s, e)
end

return M
