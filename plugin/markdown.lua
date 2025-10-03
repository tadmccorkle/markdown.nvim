vim.keymap.set(
	"n",
	"<Plug>(markdown_toggle_emphasis)",
	function()
		return require("markdown.opfunc")("markdown.inline", "toggle_emphasis")
	end,
	{
		expr = true,
		silent = true,
		desc = "Toggle emphasis around a motion",
	}
)
vim.keymap.set(
	"n",
	"<Plug>(markdown_toggle_emphasis_line)",
	function()
		return "^" .. tostring(vim.v.count1) .. "<Plug>(markdown_toggle_emphasis)g_"
	end,
	{
		expr = true,
		silent = true,
		desc = "Toggle emphasis around a line",
	}
)
vim.keymap.set(
	"x",
	"<Plug>(markdown_toggle_emphasis_visual)",
	"<Esc>gv<Cmd>lua require'markdown.inline'.toggle_emphasis_visual()<CR>",
	{
		silent = true,
		desc = "Toggle emphasis around a visual selection",
	}
)
vim.keymap.set(
	"n",
	"<Plug>(markdown_delete_emphasis)",
	"<Cmd>lua require'markdown.inline'.delete_surrounding_emphasis()<CR>",
	{
		silent = true,
		desc = "Delete emphasis around the cursor",
	}
)
vim.keymap.set(
	"n",
	"<Plug>(markdown_change_emphasis)",
	"<Cmd>lua require'markdown.inline'.change_surrounding_emphasis()<CR>",
	{
		silent = true,
		desc = "Change emphasis around the cursor",
	}
)
vim.keymap.set(
	"n",
	"<Plug>(markdown_add_link)",
	function()
		return require("markdown.opfunc")("markdown.link", "add")
	end,
	{
		expr = true,
		silent = true,
		desc = "Add link around a motion",
	}
)
vim.keymap.set(
	"x",
	"<Plug>(markdown_add_link_visual)",
	"<Esc>gv<Cmd>lua require'markdown.link'.add_visual()<CR>",
	{
		silent = true,
		desc = "Add link around a visual selection",
	}
)
vim.keymap.set(
	"n",
	"<Plug>(markdown_follow_link)",
	"<Cmd>lua require'markdown.link'.follow()<CR>",
	{
		silent = true,
		desc = "Follow link under the cursor",
	}
)
vim.keymap.set(
	"n",
	"<Plug>(markdown_follow_link_default_app)",
	"<Cmd>lua require'markdown.link'.follow({ use_default_app = true })<CR>",
	{
		silent = true,
		desc = "Follow link under the cursor using default app for non-markdown files",
	}
)
vim.keymap.set(
	"n",
	"<Plug>(markdown_go_current_heading)",
	"<Cmd>lua require'markdown.nav'.curr_heading()<CR>",
	{
		silent = true,
		desc = "Set cursor to current section heading",
	}
)
vim.keymap.set(
	"n",
	"<Plug>(markdown_go_parent_heading)",
	"<Cmd>lua require'markdown.nav'.parent_heading()<CR>",
	{
		silent = true,
		desc = "Set cursor to parent section heading",
	}
)
vim.keymap.set(
	"n",
	"<Plug>(markdown_go_next_heading)",
	"<Cmd>lua require'markdown.nav'.next_heading()<CR>",
	{
		silent = true,
		desc = "Set cursor to next section heading",
	}
)
vim.keymap.set(
	"n",
	"<Plug>(markdown_go_prev_heading)",
	"<Cmd>lua require'markdown.nav'.prev_heading()<CR>",
	{
		silent = true,
		desc = "Set cursor to previous section heading",
	}
)

local ok, nvim_ts = pcall(require, "nvim-treesitter")
if ok and vim.is_callable(nvim_ts.define_modules) then
	require("markdown").define_nvim_ts_module()
end
