local Relics = require("src.game.relics")

return {
	["relics add respects max slots"] = function()
		local r = Relics.new()
		assert(r:add({ id = "a", effect = "x", value = 1 }))
		assert(r:add({ id = "b", effect = "y", value = 2 }))
		assert(r:add({ id = "c", effect = "z", value = 3 }))
		assert(not r:add({ id = "d", effect = "w", value = 4 }), "should reject 4th relic")
	end,
	["relics get_value returns default when empty"] = function()
		local r = Relics.new()
		assert(r:get_value("nonexistent", 42) == 42, "expected default")
	end,
	["relics has_effect finds match"] = function()
		local r = Relics.new()
		r:add({ id = "a", effect = "burst_cost_mult", value = 0.6 })
		assert(r:has_effect("burst_cost_mult"), "expected match")
		assert(not r:has_effect("nonexistent"), "expected nil for missing")
	end,
	["relics get_value returns relic value"] = function()
		local r = Relics.new()
		r:add({ id = "a", effect = "light_recovery_mult", value = 1.25 })
		assert(r:get_value("light_recovery_mult", 1.0) == 1.25, "expected 1.25")
	end,
}
