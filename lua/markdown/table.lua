local api = vim.api
local M = {}

-- GFM treats every unescaped pipe as a separator, even inside code spans.
local function split(line)
	local cells, starts = {}, {}
	local start, slashes = 1, 0
	for i = 1, #line do
		local ch = line:sub(i, i)
		if ch == "|" and slashes % 2 == 0 then
			table.insert(cells, vim.trim(line:sub(start, i - 1)))
			table.insert(starts, start - 1)
			start = i + 1
		end
		slashes = ch == "\\" and slashes + 1 or 0
	end
	table.insert(cells, vim.trim(line:sub(start)))
	table.insert(starts, start - 1)
	if line:match("^%s*|") then
		table.remove(cells, 1)
		table.remove(starts, 1)
	end
	if line:match("|%s*$") and slashes == 0 and #cells > 1 then
		-- Only remove a trailing boundary when it was actually split.
		if cells[#cells] == "" then
			table.remove(cells)
			table.remove(starts)
		end
	end
	return cells, starts
end

local function read_table(node, bufnr)
	local model = {
		rows = {}, prefixes = {}, starts = {}, align = {}, tabstop = vim.bo[bufnr].tabstop,
	}
	model.first = node:start()
	local has_header = false
	for child in node:iter_children() do
		local kind = child:type()
		if kind == "pipe_table_header" or kind == "pipe_table_row"
			or kind == "pipe_table_delimiter_row" then
			local row, col, _, last = child:range()
			-- Recovery nodes can swallow unrelated text (even a fence) before their
			-- apparent header. Such nodes are not trustworthy table anchors.
			if kind == "pipe_table_header" then
				if row ~= model.first then return end
				has_header = true
			end
			local line = api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
			local cells, starts = split(line:sub(col + 1, last))
			local prefix = line:sub(1, col)
			for i, value in ipairs(starts) do starts[i] = value + col end
			if kind == "pipe_table_delimiter_row" then
				model.continuation = prefix
				model.delimiter_starts = starts
				for i, cell in ipairs(cells) do
					local left, right = cell:sub(1, 1) == ":", cell:sub(-1) == ":"
					model.align[i] = left and (right and "center" or "left")
						or (right and "right" or "none")
				end
			else
				table.insert(model.rows, cells)
				table.insert(model.prefixes, prefix)
				table.insert(model.starts, starts)
			end
			model.last = row + 1 -- exclusive, zero based
		end
	end
	if has_header and model.continuation and #model.align > 0 then return model end
end

local function normalize(model)
	local columns = #model.align
	for _, row in ipairs(model.rows) do columns = math.max(columns, #row) end
	for col = 1, columns do
		model.align[col] = model.align[col] or "none"
		for _, row in ipairs(model.rows) do row[col] = row[col] or "" end
	end
end

-- Some parser versions put body rows followed by an all-empty row in ERROR,
-- outside the preceding pipe_table. Recover only adjacent outer-pipe rows inside
-- that error span, anchored to a parser-recognized table and its container prefix.
local function recover_tail(model, bufnr, errors)
	local prefix = model.continuation
	for _, range in ipairs(errors) do
		while range[1] <= model.last and model.last < range[2] do
			local line = api.nvim_buf_get_lines(bufnr, model.last, model.last + 1, false)[1]
			if not line or line:sub(1, #prefix) ~= prefix then break end
			local text = line:sub(#prefix + 1)
			if not (text:match("^%s*|") and text:match("|%s*$")) then break end
			local cells, starts = split(text)
			for i, start in ipairs(starts) do starts[i] = start + #prefix end
			table.insert(model.rows, cells)
			table.insert(model.starts, starts)
			table.insert(model.prefixes, prefix)
			model.last = model.last + 1
		end
	end
end

---Return parsed GFM tables in document order (zero-based source ranges).
function M.tables(bufnr)
	bufnr = bufnr or api.nvim_get_current_buf()
	local root = vim.treesitter.get_parser(bufnr, "markdown"):parse()[1]:root()
	local result, errors = {}, {}
	local function walk(node)
		if node:type() == "ERROR" then
			local first, _, last, col = node:range()
			table.insert(errors, { first, last + (col > 0 and 1 or 0) })
		end
		if node:type() == "pipe_table" then
			local model = read_table(node, bufnr)
			if model then
				table.insert(result, model)
				return
			end
		end
		for child in node:iter_children() do walk(child) end
	end
	walk(root)
	for _, model in ipairs(result) do
		recover_tail(model, bufnr, errors)
		normalize(model)
	end
	return result
end

-- Expand tabs relative to the cell, measuring prefixes only at actual tab stops.
-- Ordinary cells need just one display-width measurement, not one per character.
local function cell_text(text, tabstop)
	text = vim.trim(text)
	local start, parts = 1, {}
	while true do
		local tab = text:find("\t", start, true)
		if not tab then break end
		table.insert(parts, text:sub(start, tab - 1))
		local width = vim.fn.strwidth(table.concat(parts))
		table.insert(parts, string.rep(" ", tabstop - width % tabstop))
		start = tab + 1
	end
	if start == 1 then return text end
	table.insert(parts, text:sub(start))
	return table.concat(parts)
end

---Render a table, returning lines, cell text positions, and cell bounds.
---All positions are zero-based bytes; preview omits source container prefixes.
function M.render(model, preview)
	local widths, normalized = {}, {}
	for col, align in ipairs(model.align) do
		widths[col] = 3 + (align == "center" and 2 or (align == "none" and 0 or 1))
	end
	for r, cells in ipairs(model.rows) do
		normalized[r] = {}
		for col, cell in ipairs(cells) do
			local text = cell_text(cell, model.tabstop)
			normalized[r][col] = text
			-- Expanded text has no tabs. strwidth avoids window-local soft-wrap,
			-- showbreak, and list settings affecting the table's column widths.
			widths[col] = math.max(widths[col], vim.fn.strwidth(text))
		end
	end
	local lines, positions, bounds = {}, {}, {}
	for r, row in ipairs(normalized) do
		local line = (preview and "" or model.prefixes[r]) .. "|"
		positions[r], bounds[r] = {}, {}
		for col, cell in ipairs(row) do
			local first = #line + 1
			local padding = widths[col] - vim.fn.strwidth(cell)
			local align = model.align[col]
			local left = align == "right" and padding
				or (align == "center" and math.floor(padding / 2) or 0)
			positions[r][col] = #line + 1 + left
			line = line .. " " .. string.rep(" ", left) .. cell
				.. string.rep(" ", padding - left) .. " |"
			bounds[r][col] = {
				first = first, last = #line - 2, text_end = positions[r][col] + #cell,
			}
		end
		table.insert(lines, line)
		if r == 1 then
			local delimiter = (preview and "" or model.continuation) .. "|"
			for col, align in ipairs(model.align) do
				local left = align == "left" or align == "center"
				local right = align == "right" or align == "center"
				delimiter = delimiter .. " " .. (left and ":" or "")
					.. string.rep("-", widths[col] - (left and 1 or 0) - (right and 1 or 0))
					.. (right and ":" or "") .. " |"
			end
			table.insert(lines, delimiter)
		end
	end
	return lines, positions, bounds
end

---Format whole tables intersecting an inclusive zero-based range.
---Omit the range to format the table at the cursor; (0, -1) formats all.
function M.format(first, last)
	local bufnr = api.nvim_get_current_buf()
	first = first or (api.nvim_win_get_cursor(0)[1] - 1)
	last = last or first
	local tables = M.tables(bufnr)
	local changed = false
	for i = #tables, 1, -1 do
		local model = tables[i]
		if model.last > first and (last == -1 or model.first <= last) then
			local lines = M.render(model)
			local old = api.nvim_buf_get_lines(bufnr, model.first, model.last, false)
			if not vim.deep_equal(lines, old) then
				if changed then vim.cmd("undojoin") end
				api.nvim_buf_set_lines(bufnr, model.first, model.last, false, lines)
				changed = true
			end
		end
	end
end

---Locate a source cell, treating the delimiter as the header.
function M.context()
	local cursor = api.nvim_win_get_cursor(0)
	for _, model in ipairs(M.tables()) do
		if model.first < cursor[1] and model.last >= cursor[1] then
			local row, col = math.max(1, cursor[1] - model.first - 1), 1
			local starts = cursor[1] == model.first + 2
				and model.delimiter_starts or model.starts[row]
			for i, start in ipairs(starts) do
				if start <= cursor[2] then col = i end
			end
			return model, row, col
		end
	end
end

---Dispatch an action in the table editor or directly in a Markdown buffer.
function M.action(name)
	return require("markdown.table_editor").action(name)
end

function M.edit()
	return require("markdown.table_editor").open()
end

return M
