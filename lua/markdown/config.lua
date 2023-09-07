local M = {}

M.opts = {
	inline_surround = {
		enable = true,
		mappings = {
			toggle = "gs",
			delete = "ds",
			change = "cs",
		},
		emphasis = {
			key = "i",
			txt = "*",
		},
		strong = {
			key = "b",
			txt = "**",
		},
		strikethrough = {
			key = "s",
			txt = "~~",
		},
		code = {
			key = "c",
			txt = "`",
		},
	},
}

--- Setup config with user options.
---@param cfg? table
function M.setup(cfg)
	if cfg then
		M.opts = vim.tbl_deep_extend("force", M.opts, cfg)
	end
end

return M
