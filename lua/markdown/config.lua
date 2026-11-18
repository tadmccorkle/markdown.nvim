---@alias MarkdownMapping string|boolean

---@class MappingOpts
---@field inline_surround_toggle MarkdownMapping
---@field inline_surround_toggle_line MarkdownMapping
---@field inline_surround_delete MarkdownMapping
---@field inline_surround_change MarkdownMapping
---@field link_add MarkdownMapping
---@field link_follow MarkdownMapping
---@field go_curr_heading MarkdownMapping
---@field go_parent_heading MarkdownMapping
---@field go_next_heading MarkdownMapping
---@field go_prev_heading MarkdownMapping

---@alias KeyToTxt { key: string , txt: string }

---@class InlineSurroundOpts
---@field emphasis KeyToTxt
---@field strong KeyToTxt
---@field strikethrough KeyToTxt
---@field code KeyToTxt

---@class LinkOpts
---@field paste { enable: boolean }

---@class TocOpts
---@field omit_heading string
---@field omit_section string
---@field markers string[]

---@class FollowLineRange
---@field start_line integer Parsed 1-based inclusive start (may be zero); capped at max int32
---@field end_line integer Parsed inclusive end; same as start for a single line

---@alias FollowLinkKind
---| "heading" # Destination starts with '#'; heading lookup in the source document
---| "external" # URI or URL, including 'www.' shorthand
---| "path" # Local filesystem destination, using the plugin's path-resolution rules

---@alias FollowPathType
---| "file" # Stat reports a regular file; does not imply readability
---| "directory" # Stat reports a directory
---| "other" # Stat reports another object type, e.g. a FIFO, socket, or device
---| "missing" # Stat failed with ENOENT or ENOTDIR; the target cannot be found at this path
---| "unknown" # Other stat failure, e.g. permission denied; absence was not established

---@class FollowHookOpts
---@field dest string Original destination
---@field use_default_app boolean|nil
---@field bufnr integer Source buffer
---@field kind FollowLinkKind
---@field path string|nil Absolute normalized path (path links only)
---@field fragment string|nil Interpreted path fragment, including '#'
---@field line_range FollowLineRange|nil Parsed line hint, not a guaranteed navigation target
---@field path_type FollowPathType|nil Stat follows symlinks; nil for heading/external links
---@field is_markdown boolean|nil Whether the resolved path ends in '.md'

---@class HookOpts
---@field follow_link fun(opts: FollowHookOpts, fallback: fun())|nil

---@class MarkdownConfig
---@field mappings MappingOpts|boolean
---@field inline_surround InlineSurroundOpts
---@field link LinkOpts
---@field toc TocOpts
---@field hooks HookOpts
---@field on_attach fun(bufnr: integer)|nil

---@private
---@class MarkdownConfigWrapper
---@field cfg MarkdownConfig
local MarkdownConfigWrapper = {}
MarkdownConfigWrapper.__index = MarkdownConfigWrapper

---@type MarkdownConfig
local default_cfg = {
	mappings = {
		inline_surround_toggle = "gs",
		inline_surround_toggle_line = "gss",
		inline_surround_delete = "ds",
		inline_surround_change = "cs",
		link_add = "gl",
		link_follow = "gx",
		go_curr_heading = "]c",
		go_parent_heading = "]p",
		go_next_heading = "]]",
		go_prev_heading = "[[",
	},
	inline_surround = {
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
	link = {
		paste = {
			enable = true,
		},
	},
	toc = {
		omit_heading = "toc omit heading",
		omit_section = "toc omit section",
		markers = { "-" },
	},
	hooks = {
		follow_link = nil,
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
	cfg = default_cfg,
}, MarkdownConfigWrapper)
