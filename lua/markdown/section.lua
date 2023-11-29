---@diagnostic disable: duplicate-doc-field

---@class Section
---@field name string
---@field parent Section
---@field level integer
---@field line integer
---@field omit omit_level
---@field children Section[]
local Section = {}
Section.__index = Section

---@enum omit_level
Section.OMIT_LEVEL = {
	none = 0,
	heading = 1,
	section = 2,
}

local function _new(name, parent, level, line)
	return setmetatable({
		name = name or "root",
		parent = parent,
		level = level or (parent and parent.level + 1) or 0,
		line = line or -1,
		omit = Section.OMIT_LEVEL.none,
		children = {}
	}, Section)
end

--- Adds a subsection.
---@param name string
---@param level integer
---@param line integer
---
--- Subsection `level` must be greater than the current level.
function Section:add_subsection(name, level, line)
	assert(level > self.level)

	local subsection = _new(name, self, level, line)
	table.insert(self.children, subsection)
	return subsection
end

--- Gets this section's top-most parent.
---@return Section
function Section:get_root()
	local s = self
	while s.level > 0 do
		s = s.parent
	end
	return s
end

--- Gets the parent of either the specified level relative to the current section
--- or, if no level is specified, the current section.
---@param level? integer
---@return Section|nil
---
--- Section `level`, if provided, must be greater than `0`.
function Section:get_parent(level)
	level = level or self.level
	if level > self.level then
		return self
	end

	assert(level > 0)

	local p = self.parent
	while p.level >= level do
		p = p.parent
	end

	return p
end

--- Creates a new, top-level section.
---@return Section
function Section.new()
	return _new()
end

return Section
