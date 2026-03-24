local profiles = {
	apprentice = {
		label = "Apprentice",
		map_width = 28,
		map_height = 16,
		torch_goal = 3,
		threat_budget = 4,
		player_health = 7,
		view_distance = 10.5,
	},
	stalker = {
		label = "Stalker",
		map_width = 32,
		map_height = 18,
		torch_goal = 4,
		threat_budget = 6,
		player_health = 5,
		view_distance = 9.5,
	},
	nightmare = {
		label = "Nightmare",
		map_width = 36,
		map_height = 20,
		torch_goal = 5,
		threat_budget = 8,
		player_health = 4,
		view_distance = 8.5,
	},
}

local Difficulty = {
	profiles = profiles,
}

function Difficulty.build(name, floor, mutators)
	local profile = profiles[name] or profiles.stalker
	mutators = mutators or {}

	return {
		name = name or "stalker",
		label = profile.label,
		floor = floor,
		map_width = profile.map_width + (floor - 1) * 2,
		map_height = profile.map_height + (floor - 1),
		torch_goal = math.max(2, profile.torch_goal + math.max(0, floor - 1) - (mutators.embers and 1 or 0)),
		threat_budget = profile.threat_budget + math.max(0, floor - 1) * 2 + (mutators.onslaught and 2 or 0),
		player_health = profile.player_health,
		view_distance = profile.view_distance - (floor - 1) * 0.35 + (mutators.embers and 0.8 or 0),
		flare_count = 1 + (mutators.echoes and 1 or 0),
	}
end

return Difficulty
