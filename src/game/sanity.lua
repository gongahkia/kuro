local util = require("src.core.util")

local Sanity = {}
Sanity.__index = Sanity

local tier_defs = {
	stable = {
		control_jitter = 0.0,
		view_distortion = 0.0,
		light_recovery_mult = 1.0,
		guidance_noise = 0.0,
		automap_alpha = 0.95,
		automap_pulse = 0.0,
		enemy_speed_mult = 1.0,
	},
	strained = {
		control_jitter = 0.18,
		view_distortion = 0.18,
		light_recovery_mult = 0.82,
		guidance_noise = 0.28,
		automap_alpha = 0.72,
		automap_pulse = 0.0,
		enemy_speed_mult = 1.08,
	},
	broken = {
		control_jitter = 0.36,
		view_distortion = 0.45,
		light_recovery_mult = 0.62,
		guidance_noise = 0.56,
		automap_alpha = 0.42,
		automap_pulse = 0.7,
		enemy_speed_mult = 1.16,
	},
}

local function clamp_amount(max_sanity, amount)
	return util.clamp(amount or max_sanity or 100, 0, max_sanity or 100)
end

local function tier_for_ratio(ratio)
	if ratio <= 0.32 then
		return "broken"
	end
	if ratio <= 0.68 then
		return "strained"
	end
	return "stable"
end

function Sanity.new(max_sanity)
	max_sanity = math.max(1, max_sanity or 100)
	local sanity = setmetatable({
		max_sanity = max_sanity,
		sanity = max_sanity,
		tier = "stable",
		passive_recovery_delay = 4.0,
		recovery_delay = 0,
		last_status = nil,
	}, Sanity)
	sanity.last_status = sanity:get_status()
	return sanity
end

function Sanity:get_ratio()
	return self.max_sanity > 0 and (self.sanity / self.max_sanity) or 1
end

function Sanity:get_tier()
	return self.tier
end

function Sanity:get_effects()
	local tier = tier_defs[self.tier] or tier_defs.stable
	return {
		tier = self.tier,
		control_jitter = tier.control_jitter,
		view_distortion = tier.view_distortion,
		light_recovery_mult = tier.light_recovery_mult,
		guidance_noise = tier.guidance_noise,
		automap_alpha = tier.automap_alpha,
		automap_pulse = tier.automap_pulse,
		enemy_speed_mult = tier.enemy_speed_mult,
	}
end

function Sanity:get_status()
	return {
		sanity = self.sanity,
		max_sanity = self.max_sanity,
		tier = self.tier,
		effects = self:get_effects(),
	}
end

function Sanity:set_max(max_sanity)
	self.max_sanity = math.max(1, max_sanity or self.max_sanity)
	self.sanity = clamp_amount(self.max_sanity, self.sanity)
	self.tier = tier_for_ratio(self:get_ratio())
	self.last_status = self:get_status()
end

function Sanity:apply(amount)
	self.sanity = clamp_amount(self.max_sanity, self.sanity - math.max(0, amount or 0))
	self.tier = tier_for_ratio(self:get_ratio())
	self.last_status = self:get_status()
	return self.sanity
end

function Sanity:restore(amount)
	self.sanity = clamp_amount(self.max_sanity, self.sanity + math.max(0, amount or 0))
	self.tier = tier_for_ratio(self:get_ratio())
	self.last_status = self:get_status()
	return self.sanity
end

function Sanity:can_show_automap(time_value)
	local effects = self:get_effects()
	if effects.automap_pulse <= 0 then
		return true
	end
	local pulse = math.sin((time_value or 0) * 4.2) * 0.5 + 0.5
	return pulse >= effects.automap_pulse
end

function Sanity:update(dt, context)
	context = context or {}
	local drain = 0
	local recovery = 0
	local blackout_time = context.blackout_time or 0
	local drain_mult = context.drain_mult or 1.0

	if blackout_time > 0 then
		drain = drain + 1.35
	end
	if context.in_dark_zone then
		drain = drain + 4.6
	end
	if context.in_cursed_zone then
		drain = drain + 2.0
	end
	drain = drain + math.max(0, context.enemy_pressure or 0)

	if context.in_safe_zone then
		recovery = recovery + 4.8
	end

	local passive_ok = drain < 0.35 and not context.in_dark_zone and not context.in_cursed_zone and blackout_time <= 0
	if passive_ok then
		self.recovery_delay = self.recovery_delay + dt
		if self.recovery_delay >= self.passive_recovery_delay then
			recovery = recovery + 2.6
		end
	else
		self.recovery_delay = 0
	end

	if drain > 0 then
		self:apply(drain * drain_mult * dt)
	end
	if recovery > 0 then
		self:restore(recovery * dt)
	end

	self.last_status = {
		sanity = self.sanity,
		max_sanity = self.max_sanity,
		tier = self.tier,
		drain = drain,
		recovery = recovery,
		in_safe_zone = context.in_safe_zone == true,
		in_dark_zone = context.in_dark_zone == true,
		in_cursed_zone = context.in_cursed_zone == true,
		effects = self:get_effects(),
	}
	return self.last_status
end

return Sanity
