-- Input options are recursively partial; resolved types redeclare defaulted fields as required.
-- Keep each opts/resolved pair in sync when adding configuration fields.

---@alias markdown.config.mapping string|false

---@class markdown.config.mappings.opts
---@field inline_surround_toggle? markdown.config.mapping
---@field inline_surround_toggle_line? markdown.config.mapping
---@field inline_surround_delete? markdown.config.mapping
---@field inline_surround_change? markdown.config.mapping
---@field link_add? markdown.config.mapping
---@field link_follow? markdown.config.mapping
---@field go_curr_heading? markdown.config.mapping
---@field go_parent_heading? markdown.config.mapping
---@field go_next_heading? markdown.config.mapping
---@field go_prev_heading? markdown.config.mapping

---@class markdown.config.mappings : markdown.config.mappings.opts
---@field inline_surround_toggle markdown.config.mapping
---@field inline_surround_toggle_line markdown.config.mapping
---@field inline_surround_delete markdown.config.mapping
---@field inline_surround_change markdown.config.mapping
---@field link_add markdown.config.mapping
---@field link_follow markdown.config.mapping
---@field go_curr_heading markdown.config.mapping
---@field go_parent_heading markdown.config.mapping
---@field go_next_heading markdown.config.mapping
---@field go_prev_heading markdown.config.mapping

---@class markdown.config.surround.opts
---@field key? string
---@field txt? string

---@class markdown.config.surround : markdown.config.surround.opts
---@field key string
---@field txt string

---@class markdown.config.inline_surround.opts
---@field emphasis? markdown.config.surround.opts
---@field strong? markdown.config.surround.opts
---@field strikethrough? markdown.config.surround.opts
---@field code? markdown.config.surround.opts

---@class markdown.config.inline_surround : markdown.config.inline_surround.opts
---@field emphasis markdown.config.surround
---@field strong markdown.config.surround
---@field strikethrough markdown.config.surround
---@field code markdown.config.surround

---@class markdown.config.link.paste.opts
---@field enable? boolean

---@class markdown.config.link.paste : markdown.config.link.paste.opts
---@field enable boolean

---@class markdown.config.link.opts
---@field paste? markdown.config.link.paste.opts

---@class markdown.config.link : markdown.config.link.opts
---@field paste markdown.config.link.paste

---@class markdown.config.toc.opts
---@field omit_heading? string
---@field omit_section? string
---@field markers? string[]

---@class markdown.config.toc : markdown.config.toc.opts
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

---@class markdown.config.hooks.opts
---@field follow_link? fun(opts: FollowHookOpts, fallback: fun())

---@class markdown.config.hooks : markdown.config.hooks.opts

---@class markdown.config.opts
---@field mappings? markdown.config.mappings.opts|false
---@field inline_surround? markdown.config.inline_surround.opts
---@field link? markdown.config.link.opts
---@field toc? markdown.config.toc.opts
---@field hooks? markdown.config.hooks.opts
---@field on_attach? fun(bufnr: integer)

---@class markdown.config : markdown.config.opts
---@field mappings markdown.config.mappings|false
---@field inline_surround markdown.config.inline_surround
---@field link markdown.config.link
---@field toc markdown.config.toc
---@field hooks markdown.config.hooks

---@private
---@class markdown.config.wrapper
---@field cfg markdown.config
local MarkdownConfigWrapper = {}
MarkdownConfigWrapper.__index = MarkdownConfigWrapper

---@type markdown.config
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
---@param cfg? markdown.config.opts
---@return markdown.config
function MarkdownConfigWrapper:setup(cfg)
	if cfg then
		self.cfg = vim.tbl_deep_extend("force", self.cfg, cfg)
	end
	return self.cfg
end

--- Gets the current configuration.
---@return markdown.config
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
