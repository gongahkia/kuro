local Challenges = {}

local flame_cycle = { "amber", "red", "blue" }
local loadout_cycle = { "default", "scout" }

local function has_any_mutator(mutators)
	for _, enabled in pairs(mutators) do
		if enabled then
			return true
		end
	end
	return false
end

function Challenges.daily_seed(time_value)
	local stamp = os.date("*t", time_value)
	return stamp.year * 10000 + stamp.month * 100 + stamp.day
end

function Challenges.daily_profile(time_value)
	local seed = Challenges.daily_seed(time_value)
	local mutators = {
		embers = seed % 2 == 0,
		echoes = math.floor(seed / 10) % 2 == 1,
		onslaught = math.floor(seed / 100) % 2 == 1,
	}
	if not has_any_mutator(mutators) then
		mutators.embers = true
	end
	return {
		label = os.date("%Y-%m-%d", time_value),
		seed = seed,
		difficulty = "stalker",
		mutators = mutators,
		loadout = loadout_cycle[(seed % #loadout_cycle) + 1],
		flame_color = flame_cycle[(seed % #flame_cycle) + 1],
	}
end

function Challenges.time_attack_level(elapsed)
	return math.max(0, math.floor((elapsed or 0) / 30))
end

function Challenges.time_attack_enemy_mult(level)
	return 1 + math.max(0, level or 0) * 0.08
end

function Challenges.time_attack_boss_mult(level)
	return 1 + math.max(0, level or 0) * 0.12
end

function Challenges.time_attack_spawn_interval(level)
	return math.max(7.0, 15.0 - math.max(0, level or 0) * 1.2)
end

return Challenges
