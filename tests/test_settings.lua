local Settings = require("src.core.settings")

return {
	["settings default returns table with all keys"] = function()
		local d = Settings.default()
		assert(type(d) == "table", "expected table")
		assert(d.screen_shake == true, "expected screen_shake true")
		assert(d.death_animations == true, "expected death_animations true")
		assert(d.footstep_bob == true, "expected footstep_bob true")
		assert(d.title_flicker == true, "expected title_flicker true")
		assert(type(d.master_volume) == "number", "expected master_volume number")
		assert(type(d.meta_unlocks) == "table", "expected meta_unlocks table")
		assert(d.total_runs == 0, "expected total_runs 0")
	end,
	["settings default values are independent copies"] = function()
		local a = Settings.default()
		local b = Settings.default()
		a.screen_shake = false
		assert(b.screen_shake == true, "expected independent copy")
	end,
}
