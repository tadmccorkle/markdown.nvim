local legacy = vim.g.markdown_test_legacy == true or vim.fn.has("nvim-0.12") == 0

local function root(path)
	local f = debug.getinfo(1, "S").source:sub(2)
	return vim.fn.fnamemodify(f, ":p:h:h")
		.. "/.tests/"
		.. (legacy and "legacy/" or "")
		.. (path or "")
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

local site = root("site")

vim.cmd([[set runtimepath=$VIMRUNTIME]])
vim.opt.runtimepath:append(root())
vim.opt.packpath = { site }

load("nvim-lua/plenary.nvim")
-- nvim v0.10.x-v0.11.x only supported by nvim-treesitter 'master' branch
load("nvim-treesitter/nvim-treesitter", legacy and "master" or "main")

if legacy then
	if vim.api.nvim_get_commands({}).TSUpdateSync ~= nil then
		vim.cmd("TSUpdateSync markdown markdown_inline")
	end
else
	local nvim_ts = require("nvim-treesitter")
	nvim_ts.setup({ install_dir = site })
	nvim_ts.install({ "markdown", "markdown_inline" }, { summary = true }):wait(300000)
end
