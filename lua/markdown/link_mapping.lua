local api = vim.api

local M = {}

local alias = "<Plug>(markdown_previous_follow_link)"
local states = {}

---@param bufnr integer
---@param lhs string
function M.capture(bufnr, lhs)
	if not lhs or states[bufnr] ~= nil then
		return
	end

	-- Copy the effective mapping to a private buffer-local alias. Let Neovim execute
	-- it so callbacks, expressions, remapping, and script-local RHSs keep working.
	api.nvim_buf_call(bufnr, function()
		local previous = vim.fn.maparg(lhs, "n", false, true)

		-- A user may already have mapped this key to our <Plug>. It cannot
		-- serve as its own fallback.
		local fallback = next(previous) ~= nil
			and previous.rhs ~= "<Plug>(markdown_follow_link)"
			and previous.rhs ~= "<Plug>(markdown_follow_link_default_app)"

		states[bufnr] = { lhs = lhs, previous = previous, fallback = fallback }

		if fallback then
			local mapping = vim.deepcopy(previous)
			mapping.lhs = alias
			mapping.lhsraw = api.nvim_replace_termcodes(alias, true, true, true)
			mapping.lhsrawalt = nil
			mapping.buffer = 1
			vim.fn.mapset("n", false, mapping)
			states[bufnr].alias = vim.fn.maparg(alias, "n", false, true)
		end
	end)
end

---@param bufnr integer
function M.restore(bufnr)
	local state = states[bufnr]

	if state == nil then
		return
	end

	states[bufnr] = nil

	-- Removing a buffer-local mapping exposes a global mapping, but an overwritten
	-- buffer-local mapping must be restored explicitly.
	api.nvim_buf_call(bufnr, function()
		local current = vim.fn.maparg(state.lhs, "n", false, true)
		if current.buffer == 1 and current.rhs == "<Plug>(markdown_follow_link)" then
			vim.keymap.del("n", state.lhs, { buffer = bufnr })
			if state.previous.buffer == 1 then
				vim.fn.mapset("n", false, state.previous)
			end
		end

		local fallback = vim.fn.maparg(alias, "n", false, true)
		if state.fallback and vim.deep_equal(fallback, state.alias) then
			vim.keymap.del("n", alias, { buffer = bufnr })
		end
	end)
end

---@param bufnr integer
function M.forget(bufnr)
	states[bufnr] = nil
end

function M.fallback()
	local state = states[api.nvim_get_current_buf()]
	if state and state.fallback then
		local keys = api.nvim_replace_termcodes(alias, true, false, true)
		api.nvim_feedkeys(keys, "mi", false)
	end
end

return M
