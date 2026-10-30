vim.g.markdown_test_legacy = true

local dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
dofile(dir .. "/init.lua")
