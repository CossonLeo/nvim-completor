--------------------------------------------------
--    LICENSE: MIT
--     Author: Cosson2017
--    Version: 0.3
-- CreateTime: 2019-03-11 11:10:38
-- LastUpdate: 2019-03-11 11:10:38
--       Desc: out interface
--------------------------------------------------

local complete_src = require("nvim-completor/src-manager")
local lsp = require("nvim-completor/lsp")
local context = require("nvim-completor/context")
local fuzzy = require("nvim-completor/fuzzy-match")
local log = require("nvim-completor/log")

local module = {}

local complete_engine = {
	ctx = nil,
	complete_items = nil,
	incomplete = nil,
}

function complete_engine:reset()
	self.ctx = nil
	self.complete_items = nil
	self.incomplete = nil
end

function complete_engine:text_changed(ctx)
	log.trace("text changed on complete engine")
	if not complete_src:has_complete_src() then
		log.trace("no complete src")
		return
	end

	if not ctx:can_fire_complete() then
		log.trace("ctx can not fire complete, typed: ", ctx.typed)
		return
	end

	local offset = ctx:offset_typed(self.ctx)
	if (offset and not self.incomplete) or vim.deep_equal(ctx, self.ctx) then
		log.trace("text changed trigger refresh complete items")
		complete_engine:refresh_complete(ctx)
		return
	end

	if not offset then
		log.trace("new ctx to trigger complete")
		self:reset()
		self.ctx = ctx
	end
	local incomplete = self.incomplete
	self.incomplete = nil
	complete_src:call_src(ctx, incomplete)
end

function complete_engine:add_complete_items(ctx, items, incomplete)
	log.trace("add complete items")
	if not items or #items == 0 then
		log.trace("no items to add")
		return
	end

	local offset = ctx:offset_typed(self.ctx)
	if not vim.deep_equal(self.ctx, ctx) and not offset then
		log.trace("new ctx on add items")
		return
	end

	if offset then
		log.trace("offset ctx on add items")
		self:convert_items_to_self_ctx(items, offset)
	end

	if incomplete then
		self.incomplete = self.incomplete or {}
		table.insert(self.incomplete, incomplete)
	end

	self.complete_items = self.complete_items or {}
	for _, v in pairs(items) do
		table.insert(self.complete_items, v)
	end

	self:refresh_complete()
	return
end

function complete_engine:refresh_complete(ctx)
	log.trace("complete engine refresh complete")
	local cur_ctx = ctx or context:new()
	local offset = cur_ctx:offset_typed(self.ctx)
	local matches = {}
	if offset then
		matches = fuzzy.filter_completion_items(offset, self.complete_items)
	elseif vim.deep_equal(cur_ctx, self.ctx) then
		matches = self.complete_items or matches 
	else
		log.trace("new ctx on refresh complete")
		self:reset()
		return
	end

	local mode = vim.api.nvim_get_mode().mode
	if #matches > 0 and (mode == "i" or mode == "ic" or mode == "ix") then
		log.trace("trigger vim fn complete")
		vim.fn.complete(self.ctx.pos.position.character+1, matches)
	end
end

-- 由于self.ctx 与 ctx的col可能不一样
-- 则需要将新增item转换成当前ctx, 以达到显示正确
function complete_engine:convert_items_to_self_ctx(items, offset)
	log.trace("convert items to self ctx")
	for _, item in pairs(items) do
		item.word = offset .. item.word
	end
end


return {
	reset = function() complete_engine:reset() end,
	text_changed = function(ctx) complete_engine:text_changed(ctx) end,
	add_complete_items = function(ctx, items, incomplete) complete_engine:add_complete_items(ctx, items, incomplete) end,
}

