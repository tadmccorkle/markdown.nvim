local api = vim.api

local OpFunc = setmetatable({}, {
	__call = function(self, ...)
		return self.call(...)
	end
})

--- Sets the 'operatorfunc' to the provided module's function and returns the 'g@' operator.
---@param mod string Module containing the callback function
---@param callback string 'operatorfunc' callback function
---@return "g@"
function OpFunc.call(mod, callback)
	api.nvim_set_option_value("operatorfunc", ("v:lua.require'%s'.%s"):format(mod, callback), {})
	return "g@"
end

return OpFunc
