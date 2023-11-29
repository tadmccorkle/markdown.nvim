local api = vim.api

local assert = require("luassert")
local mock = require("luassert.mock")
local say = require("say")
local util = require("luassert.util")

local function test_calls(state, args, test_call)
	local expected = util.shallowcopy(args)
	local payload = rawget(state, "payload")

	local assertion_holds = false
	local last_call
	for _, call in pairs(payload.calls) do
		last_call = call.vals[1]
		if test_call(last_call) then
			assertion_holds = true
			break
		end
	end

	util.cleararglist(args)
	util.tinsert(args, 1, expected)
	util.tinsert(args, 2, last_call)
	return assertion_holds
end

local function called_with_property_values(state, args)
	if #args ~= 1 or type(args[1]) ~= "table" then
		error("'called_with_property_values' must be called with one table argument")
	end

	return test_calls(state, args, function(call)
		if call == nil then return false end
		for key, value in pairs(args[1]) do
			if not util.deepcompare(call[key], value) then
				return false
			end
		end
		return true
	end)
end

local function called_with_property(state, args)
	if #args ~= 1 or type(args[1]) ~= "string" then
		error("'called_with_property' must be called with one string argument")
	end

	return test_calls(state, args, function(call)
		return call ~= nil and call[args[1]] ~= nil
	end)
end

say:set_namespace("en")

say:set(
	"assertion.called_with_property_values.positive",
	"Expected argument properties %s in:\n%s")
say:set(
	"assertion.called_with_property_values.negative",
	"Expected argument properties %s to not be in:\n%s")
say:set(
	"assertion.called_with_property.positive",
	"Expected argument property %s in:\n%s")
say:set(
	"assertion.called_with_property.negative",
	"Expected argument property %s to not be in:\n%s")

assert:register(
	"assertion",
	"called_with_property_values",
	called_with_property_values,
	"assertion.called_with_property_values.positive",
	"assertion.called_with_property_values.negative")
assert:register(
	"assertion",
	"called_with_property",
	called_with_property,
	"assertion.called_with_property.positive",
	"assertion.called_with_property.negative")

describe("user command arg processing", function()
	local cmd = require("markdown.cmd")

	describe("insert toc", function()
		it("can specify max level", function()
			local md_toc = require("markdown.toc")
			local toc = mock(md_toc, true)
			cmd.insert_toc({ args = "", fargs = { "2" }, range = 2, line1 = 1, line2 = 2 })
			assert.stub(toc.insert_toc).called_with_property_values({ max_level = 2 })
			cmd.insert_toc({ args = "/18", fargs = { "?" }, range = 2, line1 = 1, line2 = 2 })
			assert.stub(toc.insert_toc).called_with_property_values({ max_level = 18 })
			mock.revert(md_toc)
		end)

		it("can specify list markers", function()
			local md_toc = require("markdown.toc")
			local toc = mock(md_toc, true)
			cmd.insert_toc({ args = "", fargs = { "*", "+" }, range = 2, line1 = 1, line2 = 2 })
			assert.stub(toc.insert_toc).called_with_property_values({ markers = { "*", "+" } })
			cmd.insert_toc({ args = "/  - /*", fargs = { "?" }, range = 2, line1 = 1, line2 = 2 })
			assert.stub(toc.insert_toc).called_with_property_values({ markers = { "  - ", "*" } })
			mock.revert(md_toc)
		end)

		it("can specify max level and list markers", function()
			local md_toc = require("markdown.toc")
			local toc = mock(md_toc, true)
			cmd.insert_toc({ args = "", fargs = { "3", "*", "+" }, range = 2, line1 = 1, line2 = 2 })
			assert.stub(toc.insert_toc).called_with_property_values({ max_level = 3, markers = { "*", "+" } })
			cmd.insert_toc({ args = "/1/  - /*", fargs = { "?" }, range = 2, line1 = 1, line2 = 2 })
			assert.stub(toc.insert_toc).called_with_property_values({ max_level = 1, markers = { "  - ", "*" } })
			mock.revert(md_toc)
		end)

		it("can recover from invalid arguments", function()
			local md_toc = require("markdown.toc")
			local toc = mock(md_toc, true)
			cmd.insert_toc({ args = "/", fargs = { "?" }, range = 2, line1 = 1, line2 = 2 })
			assert.stub(toc.insert_toc).called_with_property_values({ markers = { "-" } })
			mock.revert(md_toc)
		end)

		it("can process without range", function()
			local md_toc = require("markdown.toc")
			local toc = mock(md_toc, true)
			api.nvim_win_set_cursor(0, { 1, 0 })
			cmd.insert_toc({ args = "", fargs = {}, range = 0, line1 = 1, line2 = 1 })
			assert.stub(toc.insert_toc).called_with_property_values({ start_row = 0 })
			assert.stub(toc.insert_toc).not_called_with_property("end_row")
			mock.revert(md_toc)
		end)

		it("can process with range", function()
			local md_toc = require("markdown.toc")
			local toc = mock(md_toc, true)
			cmd.insert_toc({ args = "", fargs = {}, range = 2, line1 = 1, line2 = 3 })
			assert.stub(toc.insert_toc).called_with_property_values({ start_row = 0, end_row = 2 })
			mock.revert(md_toc)
		end)
	end)

	describe("show toc", function()
		it("omits flagged headings and sections", function()
			local md_toc = require("markdown.toc")
			local toc = mock(md_toc, true)
			cmd.show_toc({ args = "", fargs = {}, range = 0, line1 = 1, line2 = 1 })
			assert.stub(toc.set_loclist_toc).called_with_property_values({ omit_flagged = true })
			mock.revert(md_toc)
		end)

		it("can specify max level", function()
			local md_toc = require("markdown.toc")
			local toc = mock(md_toc, true)
			cmd.show_toc({ args = "", fargs = { "44" }, range = 0, line1 = 1, line2 = 1 })
			assert.stub(toc.set_loclist_toc).called_with_property_values({ max_level = 44 })
			mock.revert(md_toc)
		end)
	end)

	describe("show toc all", function()
		it("can show flagged headings and sections", function()
			local md_toc = require("markdown.toc")
			local toc = mock(md_toc, true)
			cmd.show_toc_all({ args = "", fargs = {}, range = 0, line1 = 1, line2 = 1 })
			assert.stub(toc.set_loclist_toc).called_with_property_values({ omit_flagged = false })
			mock.revert(md_toc)
		end)

		it("can specify max level", function()
			local md_toc = require("markdown.toc")
			local toc = mock(md_toc, true)
			cmd.show_toc_all({ args = "", fargs = { "33" }, range = 0, line1 = 1, line2 = 1 })
			assert.stub(toc.set_loclist_toc).called_with_property_values({ max_level = 33 })
			mock.revert(md_toc)
		end)
	end)

	describe("reset list numbering", function()
		it("can reset entire buffer", function()
			local md_list = require("markdown.list")
			local list = mock(md_list, true)
			cmd.reset_list_numbering({ args = "", fargs = {}, range = 0, line1 = 1, line2 = 1 })
			assert.stub(list.reset_list_numbering).called_with(0, -1)
			mock.revert(md_list)
		end)

		it("can reset range", function()
			local md_list = require("markdown.list")
			local list = mock(md_list, true)
			cmd.reset_list_numbering({ args = "", fargs = {}, range = 2, line1 = 2, line2 = 6 })
			assert.stub(list.reset_list_numbering).called_with(1, 5)
			mock.revert(md_list)
		end)
	end)

	describe("toggle task", function()
		it("can set range", function()
			local md_list = require("markdown.list")
			local list = mock(md_list, true)
			api.nvim_win_set_cursor(0, { 1, 0 })
			cmd.toggle_task({ args = "", fargs = {}, range = 0, line1 = 1, line2 = 1 })
			assert.stub(list.toggle_task).called_with(0, 0)
			cmd.toggle_task({ args = "", fargs = {}, range = 2, line1 = 1, line2 = 3 })
			assert.stub(list.toggle_task).called_with(0, 2)
			mock.revert(md_list)
		end)
	end)
end)
