local function root(path)
	local f = debug.getinfo(1, "S").source:sub(2)
	return vim.fn.fnamemodify(f, ":p:h:h") .. "/.tests/" .. (path or "")
end

local function load(plugin)
	local name = plugin:match(".*/(.*)")
	local package_root = root("site/pack/deps/start/")
	if not vim.loop.fs_stat(package_root .. name) then
		print("Installing " .. plugin)
		vim.fn.mkdir(package_root, "p")
		vim.fn.system({
			"git",
			"clone",
			"--depth=1",
			"https://github.com/" .. plugin .. ".git",
			package_root .. "/" .. name,
		})
	end
	vim.cmd("packadd " .. name)
end

vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.opt.runtimepath:append(root())
vim.opt.packpath = { root("site") }
load("nvim-lua/plenary.nvim")
load("nvim-treesitter/nvim-treesitter")
if vim.api.nvim_get_commands({}).TSUpdateSync ~= nil then
	vim.cmd("TSUpdateSync markdown markdown_inline")
end
