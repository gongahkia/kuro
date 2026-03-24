local Meta = require("src.game.meta")

return {
	["meta records run and increments counters"] = function()
		local m = Meta.new({})
		m:record_run({ stats = { enemies_burned = 10, floors_cleared = 1, damage_taken = 5 } })
		assert(m.total_runs == 1, "expected 1 run")
		assert(m.total_burns == 10, "expected 10 burns")
	end,
	["meta unlocks after threshold"] = function()
		local m = Meta.new({})
		for _ = 1, 5 do
			m:record_run({ stats = { enemies_burned = 0, floors_cleared = 0, damage_taken = 0 } })
		end
		assert(m:is_unlocked("mutator_blacklight"), "expected blacklight unlocked after 5 runs")
	end,
	["meta victory tracking"] = function()
		local m = Meta.new({})
		for _ = 1, 3 do
			m:record_run({ difficulty = "victory", stats = { enemies_burned = 0, floors_cleared = 3, damage_taken = 0 } })
		end
		assert(m.total_victories == 3, "expected 3 victories")
		assert(m:is_unlocked("mutator_ironman"), "expected ironman unlocked after 3 victories")
	end,
	["meta save writes to settings"] = function()
		local m = Meta.new({})
		m.total_runs = 7
		m.total_burns = 55
		local settings = {}
		m:save(settings)
		assert(settings.total_runs == 7, "expected total_runs saved")
		assert(settings.total_burns == 55, "expected total_burns saved")
	end,
	["meta get_available_mutators includes unlocked"] = function()
		local m = Meta.new({ meta_unlocks = { mutator_ironman = true } })
		local mutators = m:get_available_mutators()
		local found = false
		for _, name in ipairs(mutators) do
			if name == "ironman" then found = true end
		end
		assert(found, "expected ironman in available mutators")
	end,
}
