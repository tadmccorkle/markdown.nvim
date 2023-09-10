local M = {}

M.opts = {
	inline_surround = {
		enable = true,
		mappings = {
			toggle = "gs",
			toggle_line = "gss",
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

M.on_attach = nil

--- Setup config with user options.
---@param cfg? table
---@param on_attach fun()
function M.setup(cfg, on_attach)
	if cfg then
		M.opts = vim.tbl_deep_extend("force", M.opts, cfg)
	end

	if on_attach then
		M.on_attach = on_attach
	end
end

return M
