local util = require("src.core.util")

local Hunger = {}
Hunger.__index = Hunger

function Hunger.new(max_hunger, max_sanity)
	return setmetatable({
		hunger = max_hunger or 100,
		max_hunger = max_hunger or 100,
		sanity = max_sanity or 100,
		max_sanity = max_sanity or 100,
		hunger_rate = 1.2,
		sanity_rate = 0.8,
		low_sanity_threshold = 0.3,
		starvation_tick = 0,
		starvation_interval = 3.0,
	}, Hunger)
end

function Hunger:update(dt, context)
	local rate_mult = 1.0
	if context and context.relics then
		rate_mult = context.relics:get_value("hunger_rate_mult", 1.0)
	end
	self.hunger = math.max(0, self.hunger - self.hunger_rate * rate_mult * dt)
	local sanity_mult = 1.0
	if context and context.blackout_time and context.blackout_time > 0 then
		sanity_mult = 1.6
	end
	self.sanity = math.max(0, self.sanity - self.sanity_rate * sanity_mult * dt)
	if self.hunger <= 0 then
		self.starvation_tick = self.starvation_tick + dt
		if self.starvation_tick >= self.starvation_interval then
			self.starvation_tick = self.starvation_tick - self.starvation_interval
			if context and context.damage_player then
				context.damage_player(1, "Starvation gnaws at you.")
			end
		end
	end
end

function Hunger:feed(amount)
	self.hunger = math.min(self.max_hunger, self.hunger + amount)
end

function Hunger:restore_sanity(amount)
	self.sanity = math.min(self.max_sanity, self.sanity + amount)
end

function Hunger:get_vision_distortion()
	if self.sanity / self.max_sanity > self.low_sanity_threshold then return 0 end
	return util.clamp(1 - (self.sanity / (self.max_sanity * self.low_sanity_threshold)), 0, 0.8)
end

function Hunger:get_control_jitter()
	if self.sanity / self.max_sanity > self.low_sanity_threshold then return 0 end
	return util.clamp((1 - self.sanity / (self.max_sanity * self.low_sanity_threshold)) * 0.3, 0, 0.3)
end

function Hunger:get_hunger_pct()
	return self.max_hunger > 0 and self.hunger / self.max_hunger or 1
end

function Hunger:get_sanity_pct()
	return self.max_sanity > 0 and self.sanity / self.max_sanity or 1
end

return Hunger
