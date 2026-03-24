local Stealth = require("src.game.stealth")

return {
	["stealth noise decays over time"] = function()
		local s = Stealth.new()
		s.noise_level = 5.0
		s:update(1.0, {}, false, false)
		assert(s.noise_level < 5.0, "expected noise to decay")
	end,
	["stealth crouching reduces speed"] = function()
		local s = Stealth.new()
		s:update(0, { lctrl = true }, false, false)
		assert(s:get_speed_multiplier() == 0.55, "expected 0.55 crouch speed")
	end,
	["stealth standing has full speed"] = function()
		local s = Stealth.new()
		s:update(0, {}, false, false)
		assert(s:get_speed_multiplier() == 1.0, "expected 1.0 standing speed")
	end,
	["stealth backstab from behind gives bonus"] = function()
		local s = Stealth.new()
		local enemy = { facing = 0 } -- facing east
		local player_angle = math.pi -- player facing west (toward enemy's back)
		local mult = s:backstab_multiplier(enemy, player_angle)
		assert(mult == 2.5, "expected 2.5x backstab from behind")
	end,
	["stealth frontal attack has no bonus"] = function()
		local s = Stealth.new()
		local enemy = { facing = 0 } -- facing east
		local player_angle = 0 -- player also facing east (same dir, approaching front)
		local mult = s:backstab_multiplier(enemy, player_angle)
		assert(mult == 1.0, "expected 1.0x for frontal")
	end,
	["stealth visibility decreases when crouching in dark"] = function()
		local s = Stealth.new()
		s:update(0, { lctrl = true }, false, false)
		local vis = s:compute_visibility(50, 100, 1.0) -- half light, blackout, crouching
		assert(vis < 0.5, "expected low visibility, got " .. vis)
	end,
}
