local util = require("src.core.util")

local Sprint = {}

local medal_order = { "bronze", "silver", "gold", "black_flame" }
local medal_rank = {
	bronze = 1,
	silver = 2,
	gold = 3,
	black_flame = 4,
}

local packs = {
	black_flame_circuit = {
		id = "black_flame_circuit",
		label = "Black Flame Circuit",
		seeds = {
			{
				id = "ember_arc",
				label = "Ember Arc",
				seed = 41017,
				medals = {
					apprentice = { bronze = 210, silver = 185, gold = 160, black_flame = 142 },
					stalker = { bronze = 235, silver = 205, gold = 180, black_flame = 160 },
					nightmare = { bronze = 265, silver = 232, gold = 205, black_flame = 184 },
				},
			},
			{
				id = "hollow_lane",
				label = "Hollow Lane",
				seed = 73129,
				medals = {
					apprentice = { bronze = 216, silver = 191, gold = 167, black_flame = 149 },
					stalker = { bronze = 242, silver = 212, gold = 188, black_flame = 168 },
					nightmare = { bronze = 272, silver = 241, gold = 214, black_flame = 192 },
				},
			},
			{
				id = "glass_vein",
				label = "Glass Vein",
				seed = 94421,
				medals = {
					apprentice = { bronze = 222, silver = 196, gold = 171, black_flame = 153 },
					stalker = { bronze = 248, silver = 218, gold = 193, black_flame = 173 },
					nightmare = { bronze = 279, silver = 247, gold = 220, black_flame = 198 },
				},
			},
			{
				id = "umbra_forge",
				label = "Umbra Forge",
				seed = 120337,
				medals = {
					apprentice = { bronze = 228, silver = 201, gold = 176, black_flame = 158 },
					stalker = { bronze = 255, silver = 225, gold = 199, black_flame = 178 },
					nightmare = { bronze = 286, silver = 253, gold = 226, black_flame = 203 },
				},
			},
		},
	},
}

local practice_profiles = {
	apprentice = {
		[1] = { health_ratio = 1.0, light_bonus = 0, flare_bonus = 0, wards = 0, consumables = {} },
		[2] = { health_ratio = 1.0, light_bonus = 18, flare_bonus = 1, wards = 0, consumables = { "speed_tonic" } },
		[3] = { health_ratio = 0.92, light_bonus = 28, flare_bonus = 1, wards = 1, consumables = { "speed_tonic", "calming_tonic" } },
	},
	stalker = {
		[1] = { health_ratio = 1.0, light_bonus = 0, flare_bonus = 0, wards = 0, consumables = {} },
		[2] = { health_ratio = 0.9, light_bonus = 16, flare_bonus = 1, wards = 0, consumables = { "speed_tonic" } },
		[3] = { health_ratio = 0.82, light_bonus = 24, flare_bonus = 1, wards = 1, consumables = { "speed_tonic", "calming_tonic" } },
	},
	nightmare = {
		[1] = { health_ratio = 1.0, light_bonus = 0, flare_bonus = 0, wards = 0, consumables = {} },
		[2] = { health_ratio = 0.82, light_bonus = 12, flare_bonus = 1, wards = 0, consumables = { "speed_tonic" } },
		[3] = { health_ratio = 0.72, light_bonus = 20, flare_bonus = 1, wards = 1, consumables = { "speed_tonic", "calming_tonic" } },
	},
}

local function get_pack_or_default(pack_id)
	return packs[pack_id] or packs.black_flame_circuit
end

local function sanitize_split(split)
	return {
		id = split.id,
		label = split.label,
		floor = split.floor,
		time = split.time,
		delta = split.delta,
	}
end

local function split_index(splits)
	local indexed = {}
	for _, split in ipairs(splits or {}) do
		indexed[split.id] = split
	end
	return indexed
end

function Sprint.get_default_pack_id()
	return "black_flame_circuit"
end

function Sprint.list_packs()
	local entries = {}
	for _, pack in pairs(packs) do
		entries[#entries + 1] = pack
	end
	table.sort(entries, function(left, right)
		return left.id < right.id
	end)
	return entries
end

function Sprint.get_pack(pack_id)
	return get_pack_or_default(pack_id)
end

function Sprint.get_seed(pack_id, seed_id)
	local pack = get_pack_or_default(pack_id)
	for _, entry in ipairs(pack.seeds) do
		if entry.id == seed_id then
			return entry
		end
	end
	return pack.seeds[1]
end

function Sprint.get_seed_by_index(pack_id, index)
	local pack = get_pack_or_default(pack_id)
	if #pack.seeds == 0 then
		return nil
	end
	index = util.clamp(index or 1, 1, #pack.seeds)
	return pack.seeds[index]
end

function Sprint.list_seed_ids(pack_id, include_random)
	local pack = get_pack_or_default(pack_id)
	local ids = {}
	if include_random then
		ids[#ids + 1] = "random"
	end
	for _, entry in ipairs(pack.seeds) do
		ids[#ids + 1] = entry.id
	end
	return ids
end

function Sprint.next_seed_id(pack_id, current_seed_id, step, include_random)
	local ids = Sprint.list_seed_ids(pack_id, include_random)
	local current_index = 1
	for index, value in ipairs(ids) do
		if value == current_seed_id then
			current_index = index
			break
		end
	end
	current_index = current_index + (step or 1)
	if current_index < 1 then
		current_index = #ids
	elseif current_index > #ids then
		current_index = 1
	end
	return ids[current_index]
end

function Sprint.get_seed_label(pack_id, seed_id)
	if seed_id == "random" then
		return "Random Practice"
	end
	local seed = Sprint.get_seed(pack_id, seed_id)
	return string.format("%s (%d)", seed.label, seed.seed)
end

function Sprint.category_key(difficulty, pack_id, seed_id)
	return string.format("sprint:%s:%s:%s", difficulty or "stalker", pack_id or Sprint.get_default_pack_id(), seed_id or "unknown")
end

function Sprint.get_medal_targets(pack_id, seed_id, difficulty)
	local seed = Sprint.get_seed(pack_id, seed_id)
	return util.deepcopy((seed.medals and seed.medals[difficulty or "stalker"]) or {})
end

function Sprint.evaluate_medal(pack_id, seed_id, difficulty, time_value)
	local targets = Sprint.get_medal_targets(pack_id, seed_id, difficulty)
	if not time_value or type(time_value) ~= "number" then
		return nil
	end
	local earned = nil
	for _, medal in ipairs(medal_order) do
		if targets[medal] and time_value <= targets[medal] then
			earned = medal
		end
	end
	return earned
end

function Sprint.get_pace_target(pack_id, seed_id, difficulty, elapsed)
	local targets = Sprint.get_medal_targets(pack_id, seed_id, difficulty)
	for index = #medal_order, 1, -1 do
		local medal = medal_order[index]
		local target = targets[medal]
		if target and elapsed <= target then
			return medal, target, elapsed - target
		end
	end
	if targets.bronze then
		return "bronze", targets.bronze, elapsed - targets.bronze
	end
	return nil, nil, nil
end

function Sprint.get_practice_snapshot(difficulty, floor)
	local pool = practice_profiles[difficulty or "stalker"] or practice_profiles.stalker
	return util.deepcopy(pool[floor or 1] or pool[1])
end

function Sprint.is_official_config(config)
	if not config or config.mode ~= "sprint" or config.sprint_ruleset ~= "official" then
		return false
	end
	if not config.sprint_seed_pack_id or not config.sprint_seed_id then
		return false
	end
	if config.loadout ~= "default" then
		return false
	end
	for _, enabled in pairs(config.mutators or {}) do
		if enabled then
			return false
		end
	end
	return Sprint.get_seed(config.sprint_seed_pack_id, config.sprint_seed_id) ~= nil
end

function Sprint.build_record_key(summary)
	return summary.category_key or Sprint.category_key(summary.difficulty_id or summary.difficulty_key or summary.difficulty_name or summary.difficulty_label, summary.sprint_seed_pack_id, summary.sprint_seed_id)
end

function Sprint.update_record(records, summary, replay_file)
	records = records or {}
	if not summary or summary.mode ~= "sprint" or summary.sprint_ruleset ~= "official" or summary.outcome ~= "victory" or not summary.official_record_eligible then
		return records, {
			eligible = false,
			updated = false,
			new_pb = false,
			new_best_splits = false,
		}
	end

	local key = summary.category_key or Sprint.category_key(summary.difficulty_id, summary.sprint_seed_pack_id, summary.sprint_seed_id)
	local record = util.deepcopy(records[key] or {})
	local previous_medal = record.medal
	local best_split_map = split_index(record.best_splits or {})
	local new_best_splits = false

	for _, split in ipairs(summary.splits or {}) do
		local current = best_split_map[split.id]
		if not current or split.time < current.time then
			best_split_map[split.id] = sanitize_split(split)
			new_best_splits = true
		end
	end

	local best_splits = {}
	for _, split in ipairs(summary.splits or {}) do
		best_splits[#best_splits + 1] = best_split_map[split.id] or sanitize_split(split)
	end

	local new_pb = record.best_time == nil or summary.duration < record.best_time
	local medal = summary.medal or Sprint.evaluate_medal(summary.sprint_seed_pack_id, summary.sprint_seed_id, summary.difficulty_id, summary.duration)
	local best_medal = record.medal
	if medal and (not best_medal or medal_rank[medal] > medal_rank[best_medal]) then
		best_medal = medal
	end

	record.best_time = new_pb and summary.duration or record.best_time
	record.best_splits = best_splits
	record.medal = best_medal
	if replay_file then
		record.pb_replay = replay_file
	elseif new_pb then
		record.pb_replay = nil
	end
	records[key] = record

	return records, {
		eligible = true,
		updated = new_pb or new_best_splits or best_medal ~= previous_medal,
		new_pb = new_pb,
		new_best_splits = new_best_splits,
		medal = medal,
		best_medal = best_medal,
		record = util.deepcopy(record),
		category_key = key,
	}
end

return Sprint
