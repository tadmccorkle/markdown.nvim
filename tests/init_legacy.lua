local function root(path)
	local f = debug.getinfo(1, "S").source:sub(2)
	return vim.fn.fnamemodify(f, ":p:h:h") .. "/.tests/legacy/" .. (path or "")
end

local function exists(path)
	if vim.uv then
		return vim.uv.fs_stat(path)
	elseif vim.loop then
		return vim.loop.fs_stat(path)
	else
		return false
	end
end

local function load(plugin, branch)
	local name = plugin:match(".*/(.*)")
	local package_root = root("site/pack/deps/start/")
	if not exists(package_root .. name) then
		print("Installing " .. plugin)

		local cmd = { "git", "clone", "--depth=1" }
		if branch then
			table.insert(cmd, "--branch=" .. branch)
		end
		table.insert(cmd, "https://github.com/" .. plugin .. ".git")
		table.insert(cmd, package_root .. "/" .. name)

		vim.fn.mkdir(package_root, "p")
		vim.fn.system(cmd)
	end
	vim.cmd("packadd " .. name)
end

vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.opt.runtimepath:append(root())
vim.opt.packpath = { root("site") }

load("nvim-lua/plenary.nvim")
load("nvim-treesitter/nvim-treesitter", "master")

if vim.api.nvim_get_commands({}).TSUpdateSync ~= nil then
	vim.cmd("TSUpdateSync markdown markdown_inline")
end
