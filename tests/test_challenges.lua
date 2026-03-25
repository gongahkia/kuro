local Challenges = require("src.game.challenges")

return {
	["daily seed uses calendar date"] = function()
		local stamp = os.time({ year = 2026, month = 3, day = 25, hour = 12, min = 0, sec = 0 })
		assert(Challenges.daily_seed(stamp) == 20260325, "expected YYYYMMDD daily seed")
	end,

	["daily profile locks stalker and at least one mutator"] = function()
		local profile = Challenges.daily_profile(os.time({ year = 2026, month = 3, day = 25, hour = 12, min = 0, sec = 0 }))
		assert(profile.difficulty == "stalker", "daily challenge should lock stalker difficulty")
		local enabled = false
		for _, value in pairs(profile.mutators) do
			if value then enabled = true end
		end
		assert(enabled, "expected at least one enabled daily mutator")
	end,

	["time attack helpers scale with level"] = function()
		assert(Challenges.time_attack_level(91) == 3, "expected three time-attack levels")
		assert(Challenges.time_attack_enemy_mult(3) > Challenges.time_attack_enemy_mult(1), "enemy multiplier should scale up")
		assert(Challenges.time_attack_spawn_interval(3) < Challenges.time_attack_spawn_interval(1), "spawn interval should tighten")
	end,
}
