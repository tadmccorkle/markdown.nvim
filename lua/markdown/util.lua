local M = {}

--- Removes comments and new lines.
---@param s string
---@return string
function M.sanitize(s)
	local sanitized, _ = s:gsub("(%s-)\n(%s*)", " ")
			:gsub("<!--(.-)-->", "")
			:gsub("^%s*(.-)%s*$", "%1")
	return sanitized
end

---@param s string
---@return string
function M.slugify(s)
	return s:gsub(" ", "-"):lower()
end

return M
