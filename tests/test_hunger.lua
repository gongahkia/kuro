local Hunger = require("src.game.hunger")

return {
	["hunger decreases over time"] = function()
		local h = Hunger.new(100, 100)
		h:update(1.0, {})
		assert(h.hunger < 100, "expected hunger to decrease")
	end,
	["hunger feed restores hunger"] = function()
		local h = Hunger.new(100, 100)
		h.hunger = 50
		h:feed(20)
		assert(h.hunger == 70, "expected 70 after feed")
	end,
	["hunger feed caps at max"] = function()
		local h = Hunger.new(100, 100)
		h:feed(200)
		assert(h.hunger == 100, "expected capped at 100")
	end,
	["sanity decreases over time"] = function()
		local h = Hunger.new(100, 100)
		h:update(1.0, {})
		assert(h.sanity < 100, "expected sanity to decrease")
	end,
	["low sanity produces vision distortion"] = function()
		local h = Hunger.new(100, 100)
		h.sanity = 5
		local distortion = h:get_vision_distortion()
		assert(distortion > 0, "expected distortion when sanity low")
	end,
	["high sanity produces no distortion"] = function()
		local h = Hunger.new(100, 100)
		assert(h:get_vision_distortion() == 0, "expected no distortion at full sanity")
	end,
	["restore sanity caps at max"] = function()
		local h = Hunger.new(100, 100)
		h.sanity = 80
		h:restore_sanity(50)
		assert(h.sanity == 100, "expected capped at 100")
	end,
}
