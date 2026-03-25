local util = require("src.core.util")

local Stealth = {}
Stealth.__index = Stealth

function Stealth.new()
	return setmetatable({
		crouching = false,
		noise_level = 0,
		noise_decay = 8.0,
	}, Stealth)
end

function Stealth:update(dt, keys, is_using_light, is_moving)
	if keys and keys.lctrl then
		self.crouching = true
	else
		self.crouching = false
	end
	local noise_add = 0
	if is_moving then noise_add = noise_add + 1.0 end
	if is_using_light then noise_add = noise_add + 2.0 end
	if self.crouching then noise_add = noise_add * 0.3 end
	self.noise_level = math.max(0, self.noise_level + noise_add * dt - self.noise_decay * dt)
end

function Stealth:add_burst_noise()
	self.noise_level = self.noise_level + 5.0
end

function Stealth:get_noise_radius()
	return self.noise_level * 0.8
end

function Stealth:get_speed_multiplier(is_sliding)
	if is_sliding then return 1.0 end
	return self.crouching and 0.55 or 1.0
end

function Stealth:is_crouching()
	return self.crouching
end

function Stealth:compute_visibility(light_charge, max_charge, blackout_time)
	local light_factor = (max_charge > 0) and (light_charge / max_charge) or 0
	local dark_bonus = blackout_time > 0 and 0.3 or 0
	local crouch_bonus = self.crouching and 0.3 or 0
	return util.clamp(light_factor - dark_bonus - crouch_bonus, 0.1, 1.0)
end

function Stealth:backstab_multiplier(enemy, player_angle)
	if not enemy.facing then return 1.0 end
	local angle_behind = enemy.facing + math.pi
	local diff = math.abs(((player_angle - angle_behind + math.pi) % (math.pi * 2)) - math.pi)
	return diff < math.rad(60) and 2.5 or 1.0
end

return Stealth
