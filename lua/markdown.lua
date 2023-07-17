local api = vim.api
local ts = vim.treesitter

local M = {}

local query = ts.query.parse("markdown", [[
	(list_item
		[
		 (list_marker_minus) @minus
		 (list_marker_star) @star
		 (list_marker_plus) @plus
		]
		(_ (inline) @inline)?)
]])
local minus_id = 1;
local star_id = 2;
local plus_id = 3;
local inline_id = 4;

-- TODO: use modifier key or unique mapping for "improved" behaviors by default

local key_cr = api.nvim_replace_termcodes("<CR>", true, true, true)

-- row and col are 0-based
local function find_match_containing(row, col)
	local t = ts.get_parser(0, "markdown"):parse()[1]
	for _, match, _ in query:iter_matches(t:root(), 0, 0, -1) do
		for _, node in pairs(match) do
			if ts.node_contains(node, { row, col, row, col }) then
				return match
			end
		end
	end
end

local function insert_list_item_for_match(match)
	local list_marker
	if match[minus_id] ~= nil then
		list_marker = "-"
	elseif match[star_id] ~= nil then
		list_marker = "*"
	elseif match[plus_id] ~= nil then
		list_marker = "+"
	end
	-- TODO: some edge cases causing weird behavior here
	-- * <CR> when cursor is directly on list marker
	-- * o/O in block_continuation of previous list item
	api.nvim_feedkeys(list_marker .. " ", "i", true)
end

local function handle_key(k)
	local cursor = api.nvim_win_get_cursor(0) -- 1-based row
	local cursor_match = find_match_containing(cursor[1] - 1, cursor[2])
	if cursor_match == nil then
		return
	end

	local mode = api.nvim_get_mode().mode
	if k == key_cr and mode == "i" then
		if cursor_match[inline_id] == nil then
			api.nvim_buf_set_lines(0, cursor[1] - 1, cursor[1], true, { "" })
		else
			insert_list_item_for_match(cursor_match)
		end
	elseif (k == "o" or k == "O") and mode == "n" then
		insert_list_item_for_match(cursor_match)
	end
end

local group = api.nvim_create_augroup("markdown.nvim", {})
local ns = api.nvim_create_namespace("markdown.nvim")
local function handle_key_autocmd_opts(pattern)
	return {
		group = group,
		pattern = pattern,
		callback = function()
			vim.on_key(handle_key, ns)
		end
	}
end

api.nvim_clear_autocmds({ group = group })
api.nvim_create_autocmd("BufEnter", handle_key_autocmd_opts({ "*.md" }))
api.nvim_create_autocmd("FileType", handle_key_autocmd_opts("markdown"))
api.nvim_create_autocmd("BufLeave", {
	group = group,
	pattern = { "*.md" },
	callback = function()
		---@diagnostic disable-next-line: param-type-mismatch
		vim.on_key(nil, ns)
	end,
})

-- function for testing
function MP()
end

return M
