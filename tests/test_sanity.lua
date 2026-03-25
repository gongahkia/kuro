local Sanity = require("src.game.sanity")

return {
	["sanity enters strained and broken tiers"] = function()
		local sanity = Sanity.new(100)
		sanity:apply(40)
		assert(sanity:get_tier() == "strained", "expected strained tier")
		sanity:apply(35)
		assert(sanity:get_tier() == "broken", "expected broken tier")
	end,

	["sanity recovers toward stability"] = function()
		local sanity = Sanity.new(100)
		sanity:apply(70)
		sanity:restore(50)
		assert(sanity:get_tier() == "stable", "expected stable after recovery")
	end,

	["sanity update drains in dark zones and recovers in safe zones"] = function()
		local sanity = Sanity.new(100)
		sanity:update(1.0, { in_dark_zone = true, enemy_pressure = 1.0 })
		assert(sanity.sanity < 100, "expected sanity drain in danger")
		local after_drain = sanity.sanity
		sanity:update(5.0, { in_safe_zone = true, enemy_pressure = 0 })
		assert(sanity.sanity > after_drain, "expected safe-zone recovery")
	end,

	["broken sanity can hide the automap between pulses"] = function()
		local sanity = Sanity.new(100)
		sanity:apply(80)
		assert(sanity:get_tier() == "broken", "expected broken tier")
		assert(sanity:can_show_automap(0) == false, "expected hidden automap at trough")
	end,
}
