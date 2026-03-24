local FX = require("src.render.fx")

return {
	["fx shake decays to zero"] = function()
		local fx = FX.new({ screen_shake = true })
		fx:trigger_shake(1.0, 0.2)
		assert(fx.shake_time > 0, "expected shake_time > 0")
		for _ = 1, 20 do fx:update(0.02) end
		assert(fx.shake_time <= 0, "expected shake to decay")
		assert(fx.shake_offset_x == 0, "expected offset reset")
	end,
	["fx shake disabled by settings"] = function()
		local fx = FX.new({ screen_shake = false })
		fx:trigger_shake(1.0, 0.5)
		assert(fx.shake_time == 0, "expected no shake when disabled")
	end,
	["fx bob returns 0 when not moving"] = function()
		local fx = FX.new({ footstep_bob = true })
		assert(fx:get_bob_offset(false) == 0, "expected 0 when not moving")
	end,
	["fx bob returns nonzero when moving"] = function()
		local fx = FX.new({ footstep_bob = true })
		fx.bob_phase = math.pi * 0.5 -- peak of sin
		local offset = fx:get_bob_offset(true)
		assert(offset ~= 0, "expected nonzero bob")
	end,
	["fx bob disabled by settings"] = function()
		local fx = FX.new({ footstep_bob = false })
		fx.bob_phase = math.pi * 0.5
		assert(fx:get_bob_offset(true) == 0, "expected 0 when disabled")
	end,
	["fx death particles accumulate and decay"] = function()
		local fx = FX.new({ death_animations = true })
		fx:trigger_death_anim(100, 100, "stalker")
		assert(#fx.death_particles == 1, "expected 1 particle group")
		for _ = 1, 60 do fx:update(0.016) end
		assert(#fx.death_particles == 0, "expected particle group removed after duration")
	end,
}
