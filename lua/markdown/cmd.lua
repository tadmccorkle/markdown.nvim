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
