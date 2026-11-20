-- A branching operation history, independent of the scratch buffer's text undo.
local M = {}

function M.new(state)
	local history = { nodes = {}, current = 1 }
	history.nodes[1] = { state = vim.deepcopy(state), children = {} }

	function history.push(next_state)
		local parent = history.nodes[history.current]
		local index = #history.nodes + 1
		history.nodes[index] = {
			state = vim.deepcopy(next_state), parent = history.current, children = {},
		}
		table.insert(parent.children, index)
		parent.preferred = index
		history.current = index
	end

	function history.jump(index)
		local node = history.nodes[index]
		if not node then return end
		history.current = index
		-- Make redo follow the branch just visited.
		local child = index
		while history.nodes[child].parent do
			local parent = history.nodes[child].parent
			history.nodes[parent].preferred = child
			child = parent
		end
		return vim.deepcopy(node.state)
	end

	function history.undo()
		return history.jump(history.nodes[history.current].parent)
	end

	function history.redo()
		return history.jump(history.nodes[history.current].preferred)
	end

	function history.earlier(delta)
		return history.jump(history.current + delta)
	end

	return history
end

return M
