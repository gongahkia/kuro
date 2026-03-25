local util = require("src.core.util")
local Style = {}
Style.__index = Style
local RANKS = { "D", "C", "B", "A", "S", "SS" }
local RANK_THRESHOLDS = { 0, 15, 35, 60, 85, 100 }
local DECAY_RATE = 8.0 -- points/sec when idle
local VARIETY_BONUS = 1.4
local REPEAT_PENALTY = 0.6

function Style.new()
	return setmetatable({
		score = 0,
		max_score = 100,
		rank_index = 1,
		recent_techs = {},
		tech_window = 5.0,
		flash_timer = 0,
	}, Style)
end

function Style:notify_tech(tech_name, clock)
	local multiplier = 1.0
	local unique = true
	for _, entry in ipairs(self.recent_techs) do
		if entry.tech == tech_name then
			unique = false
			break
		end
	end
	multiplier = unique and VARIETY_BONUS or REPEAT_PENALTY
	local base_points = { slide_jump = 12, bhop = 8, wall_kick_bhop = 18, burn_dash_bhop = 15, bhop_wall_run = 14 }
	local points = (base_points[tech_name] or 10) * multiplier
	self.score = math.min(self.max_score, self.score + points)
	self.recent_techs[#self.recent_techs + 1] = { tech = tech_name, time = clock }
	self.flash_timer = 0.3
	self:_update_rank()
end

function Style:update(dt, clock)
	self.flash_timer = math.max(0, self.flash_timer - dt)
	for i = #self.recent_techs, 1, -1 do
		if clock - self.recent_techs[i].time > self.tech_window then
			table.remove(self.recent_techs, i)
		end
	end
	if self.flash_timer <= 0 then
		self.score = math.max(0, self.score - DECAY_RATE * dt)
	end
	self:_update_rank()
end

function Style:_update_rank()
	self.rank_index = 1
	for i = #RANK_THRESHOLDS, 1, -1 do
		if self.score >= RANK_THRESHOLDS[i] then
			self.rank_index = i
			break
		end
	end
end

function Style:get_rank()
	return RANKS[self.rank_index] or "D"
end

function Style:get_score()
	return self.score
end

function Style:get_flash()
	return self.flash_timer
end

function Style:reset()
	self.score = 0
	self.rank_index = 1
	self.recent_techs = {}
	self.flash_timer = 0
end

return Style
