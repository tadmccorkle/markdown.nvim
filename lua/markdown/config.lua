---@class InlineSurroundMappings
---@field toggle string
---@field toggle_line string
---@field delete string
---@field change string

---@alias KeyToTxt { key: string , txt: string }

---@class InlineSurroundOpts
---@field enable boolean
---@field mappings InlineSurroundMappings
---@field emphasis KeyToTxt
---@field strong KeyToTxt
---@field strikethrough KeyToTxt
---@field code KeyToTxt

---@class MarkdownConfig
---@field inline_surround InlineSurroundOpts
---@field on_attach fun()|nil

---@private
---@class MarkdownConfigWrapper
---@field cfg MarkdownConfig
local MarkdownConfigWrapper = {}
MarkdownConfigWrapper.__index = MarkdownConfigWrapper

--- Setup config with user options.
---@param cfg? MarkdownConfig
function MarkdownConfigWrapper:setup(cfg)
	if cfg then
		self.cfg = vim.tbl_deep_extend("force", self.cfg, cfg)
	end
end

--- Gets the current configuration.
---@return MarkdownConfig
function MarkdownConfigWrapper:get()
	return self.cfg
end

return setmetatable({
	cfg = {
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
		on_attach = nil,
	}
}, MarkdownConfigWrapper)
