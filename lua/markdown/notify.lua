local M = {}

---@param level integer
---@return fun(fmt: string, ...: any)
local function notify(level)
	return vim.schedule_wrap(function(s, ...)
		vim.notify("markdown.nvim: " .. s:format(...), level)
	end)
end

---@param fmt string Format string
---@param ... any Optional format string arguments
function M.info(fmt, ...)
	notify(vim.log.levels.INFO)(fmt, ...)
end

---@param fmt string Format string
---@param ... any Optional format string arguments
function M.warn(fmt, ...)
	notify(vim.log.levels.WARN)(fmt, ...)
end

---@param fmt string Format string
---@param ... any Optional format string arguments
function M.error(fmt, ...)
	notify(vim.log.levels.ERROR)(fmt, ...)
end

return M
