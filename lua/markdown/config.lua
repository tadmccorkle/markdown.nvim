---@class InlineSurroundMappings
---@field toggle string|boolean
---@field toggle_line string|boolean
---@field delete string|boolean
---@field change string|boolean

---@alias KeyToTxt { key: string , txt: string }

---@class InlineSurroundOpts
---@field mappings InlineSurroundMappings
---@field emphasis KeyToTxt
---@field strong KeyToTxt
---@field strikethrough KeyToTxt
---@field code KeyToTxt

---@class MarkdownConfig
---@field inline_surround InlineSurroundOpts
---@field on_attach fun(bufnr: integer)|nil

---@private
---@class MarkdownConfigWrapper
---@field cfg MarkdownConfig
local MarkdownConfigWrapper = {}
MarkdownConfigWrapper.__index = MarkdownConfigWrapper

---@type MarkdownConfig
local default_cfg = {
	inline_surround = {
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
	on_attach = nil,
}

--- Setup config with user options.
---@param cfg? MarkdownConfig
---@return MarkdownConfig
function MarkdownConfigWrapper:setup(cfg)
	if cfg then
		self.cfg = vim.tbl_deep_extend("force", self.cfg, cfg)
	end
	return self.cfg
end

--- Gets the current configuration.
---@return MarkdownConfig
function MarkdownConfigWrapper:get()
	return self.cfg
end

--- Resets the current configuration defaults.
function MarkdownConfigWrapper:reset()
	self.cfg = default_cfg
end

return setmetatable({
	cfg = default_cfg
}, MarkdownConfigWrapper)
