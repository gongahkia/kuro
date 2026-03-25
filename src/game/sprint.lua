local util = require("src.core.util")

local Sprint = {}

local medal_order = { "bronze", "silver", "gold", "black_flame" }
local medal_rank = {
	bronze = 1,
	silver = 2,
	gold = 3,
	black_flame = 4,
}

local split_plan = {
	{ id = "floor_1_start", label = "Floor 1 Start", floor = 1 },
	{ id = "floor_1_clear", label = "Floor 1 Clear", floor = 1 },
	{ id = "floor_2_start", label = "Floor 2 Start", floor = 2 },
	{ id = "floor_2_clear", label = "Floor 2 Clear", floor = 2 },
	{ id = "floor_3_start", label = "Floor 3 Start", floor = 3 },
	{ id = "boss_start", label = "Boss Start", floor = 3 },
	{ id = "final_anchor_lit", label = "Final Anchor Lit", floor = 3 },
	{ id = "boss_kill", label = "Boss Kill", floor = 3 },
	{ id = "run_finish", label = "Run Finish", floor = 3 },
}

local floor_profiles = {
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

local function medals(apprentice, stalker, nightmare)
	return {
		apprentice = apprentice,
		stalker = stalker,
		nightmare = nightmare,
	}
end

local function route_manifest(floor1, floor2, floor3)
	return {
		[1] = floor1,
		[2] = floor2,
		[3] = floor3,
	}
end

local function standard_route(minimum_room, bonus_room, dark_from, dark_to, flare_from, flare_to, burn_from, burn_to)
	return {
		minimum_torch = {
			pickup_room = minimum_room,
			bonus_room = bonus_room,
			torch_budget = 1,
			bailout_room = bonus_room,
			path_from_main = math.max(1, math.min(2, minimum_room)),
		},
		dark_lane = {
			from_candidate = dark_from,
			to_main = dark_to,
			drain_mult = 1.7,
			bailout_room = bonus_room,
			visibility_ceiling = 0.96,
		},
		flare_line = {
			from_main = flare_from,
			to_candidate = flare_to,
			checkpoint_count = 2,
			boost_window = 1.1,
			boost_extension = 0.32,
			speed_mult = 1.46,
		},
		burn_lane = {
			from_candidate = burn_from,
			to_main = burn_to,
			gate_count = 2,
			min_charge = 0.72,
			dash_extension = 0.08,
			light_refund = 4,
		},
	}
end

local function boss_route(primary_pillar, secondary_pillar, anchor_order, weaken_bonus)
	return {
		pillar_route = {
			primary_pillar = primary_pillar,
			secondary_pillar = secondary_pillar,
			anchor_order = anchor_order,
			weaken_bonus = weaken_bonus,
			hazard_mult = 0.76,
			anchor_range_bonus = 0.7,
			anchor_restore = 12,
		},
	}
end

local function build_drills(pack_id, seed_id)
	return {
		{
			id = string.format("drill:%s:%s:shortcut_entry", pack_id, seed_id),
			label = "Shortcut Entry Drill",
			floor = 1,
			route_id = "burn_lane_1",
			goal = { type = "reach_route_end", require = "burn_dash" },
			snapshot = { light_bonus = 8, flare_bonus = 0, consumables = {} },
		},
		{
			id = string.format("drill:%s:%s:minimum_torch", pack_id, seed_id),
			label = "Minimum Torch Drill",
			floor = 1,
			route_id = "minimum_torch_1",
			goal = { type = "collect_route_pickup", route_role = "minimum_torch" },
			snapshot = { light_bonus = 4, flare_bonus = 0, consumables = {} },
		},
		{
			id = string.format("drill:%s:%s:flare_line", pack_id, seed_id),
			label = "Flare Line Drill",
			floor = 2,
			route_id = "flare_line_2",
			goal = { type = "reach_route_end", require = "flare_boost" },
			snapshot = { light_bonus = 12, flare_bonus = 2, consumables = { "speed_tonic" } },
		},
		{
			id = string.format("drill:%s:%s:pillar_anchor", pack_id, seed_id),
			label = "Pillar Anchor Drill",
			floor = 3,
			route_id = "pillar_route_3",
			goal = { type = "pillar_anchor", required_pillars = 1, required_anchors = 1 },
			snapshot = { light_bonus = 24, flare_bonus = 1, wards = 1, consumables = { "calming_tonic", "speed_tonic" } },
		},
	}
end

local function make_seed(id, label, seed, medal_targets, manifest, pack_id)
	return {
		id = id,
		label = label,
		seed = seed,
		medals = medal_targets,
		route_manifest = manifest,
		drills = build_drills(pack_id, id),
	}
end

local packs = {
	black_flame_circuit = {
		id = "black_flame_circuit",
		label = "Black Flame Circuit",
		version = "1.1.0",
		seeds = {
			make_seed("ember_arc", "Ember Arc", 41017, medals(
				{ bronze = 210, silver = 185, gold = 160, black_flame = 142 },
				{ bronze = 235, silver = 205, gold = 180, black_flame = 160 },
				{ bronze = 265, silver = 232, gold = 205, black_flame = 184 }
			), route_manifest(
				standard_route(1, 4, 4, 5, 2, 3, 3, 4),
				standard_route(2, 5, 5, 6, 3, 4, 4, 5),
				boss_route(1, 4, { 1, 3, 2 }, 0.72)
			), "black_flame_circuit"),
			make_seed("hollow_lane", "Hollow Lane", 73129, medals(
				{ bronze = 216, silver = 191, gold = 167, black_flame = 149 },
				{ bronze = 242, silver = 212, gold = 188, black_flame = 168 },
				{ bronze = 272, silver = 241, gold = 214, black_flame = 192 }
			), route_manifest(
				standard_route(2, 4, 3, 4, 2, 2, 4, 4),
				standard_route(3, 6, 4, 5, 4, 3, 5, 5),
				boss_route(2, 3, { 2, 1, 3 }, 0.68)
			), "black_flame_circuit"),
			make_seed("glass_vein", "Glass Vein", 94421, medals(
				{ bronze = 222, silver = 196, gold = 171, black_flame = 153 },
				{ bronze = 248, silver = 218, gold = 193, black_flame = 173 },
				{ bronze = 279, silver = 247, gold = 220, black_flame = 198 }
			), route_manifest(
				standard_route(3, 5, 2, 4, 3, 2, 4, 3),
				standard_route(1, 4, 5, 5, 2, 4, 3, 4),
				boss_route(1, 2, { 3, 1, 2 }, 0.7)
			), "black_flame_circuit"),
			make_seed("umbra_forge", "Umbra Forge", 120337, medals(
				{ bronze = 228, silver = 201, gold = 176, black_flame = 158 },
				{ bronze = 255, silver = 225, gold = 199, black_flame = 178 },
				{ bronze = 286, silver = 253, gold = 226, black_flame = 203 }
			), route_manifest(
				standard_route(4, 2, 4, 3, 3, 2, 2, 4),
				standard_route(2, 5, 3, 6, 4, 5, 4, 4),
				boss_route(4, 1, { 2, 3, 1 }, 0.75)
			), "black_flame_circuit"),
		},
	},
	ash_spine_trials = {
		id = "ash_spine_trials",
		label = "Ash Spine Trials",
		version = "1.1.0",
		seeds = {
			make_seed("sinder_step", "Cinder Step", 21551, medals(
				{ bronze = 214, silver = 189, gold = 164, black_flame = 146 },
				{ bronze = 239, silver = 209, gold = 184, black_flame = 164 },
				{ bronze = 269, silver = 238, gold = 211, black_flame = 189 }
			), route_manifest(
				standard_route(1, 3, 4, 4, 2, 2, 3, 4),
				standard_route(3, 6, 5, 6, 4, 4, 3, 5),
				boss_route(2, 4, { 1, 2, 3 }, 0.69)
			), "ash_spine_trials"),
			make_seed("ember_spoke", "Ember Spoke", 31897, medals(
				{ bronze = 218, silver = 193, gold = 168, black_flame = 150 },
				{ bronze = 244, silver = 214, gold = 189, black_flame = 169 },
				{ bronze = 274, silver = 243, gold = 216, black_flame = 194 }
			), route_manifest(
				standard_route(2, 4, 5, 5, 3, 3, 4, 4),
				standard_route(1, 5, 4, 6, 2, 5, 5, 4),
				boss_route(1, 3, { 2, 1, 3 }, 0.73)
			), "ash_spine_trials"),
			make_seed("coal_talon", "Coal Talon", 42773, medals(
				{ bronze = 223, silver = 198, gold = 172, black_flame = 154 },
				{ bronze = 249, silver = 219, gold = 194, black_flame = 174 },
				{ bronze = 280, silver = 248, gold = 221, black_flame = 199 }
			), route_manifest(
				standard_route(4, 5, 2, 4, 2, 3, 3, 4),
				standard_route(2, 4, 5, 6, 4, 4, 4, 5),
				boss_route(3, 4, { 3, 2, 1 }, 0.71)
			), "ash_spine_trials"),
			make_seed("slag_waltz", "Slag Waltz", 53661, medals(
				{ bronze = 229, silver = 204, gold = 178, black_flame = 159 },
				{ bronze = 255, silver = 225, gold = 200, black_flame = 179 },
				{ bronze = 286, silver = 254, gold = 227, black_flame = 204 }
			), route_manifest(
				standard_route(3, 2, 4, 5, 3, 2, 4, 4),
				standard_route(1, 6, 3, 6, 2, 3, 5, 5),
				boss_route(2, 1, { 1, 3, 2 }, 0.76)
			), "ash_spine_trials"),
		},
	},
	obsidian_descent = {
		id = "obsidian_descent",
		label = "Obsidian Descent",
		version = "1.1.0",
		seeds = {
			make_seed("black_glint", "Black Glint", 64217, medals(
				{ bronze = 212, silver = 188, gold = 163, black_flame = 145 },
				{ bronze = 238, silver = 208, gold = 183, black_flame = 163 },
				{ bronze = 268, silver = 237, gold = 210, black_flame = 188 }
			), route_manifest(
				standard_route(2, 3, 5, 5, 3, 2, 4, 4),
				standard_route(1, 5, 4, 6, 4, 4, 3, 5),
				boss_route(4, 2, { 2, 3, 1 }, 0.7)
			), "obsidian_descent"),
			make_seed("void_hinge", "Void Hinge", 75941, medals(
				{ bronze = 219, silver = 194, gold = 169, black_flame = 151 },
				{ bronze = 245, silver = 215, gold = 190, black_flame = 170 },
				{ bronze = 275, silver = 244, gold = 217, black_flame = 195 }
			), route_manifest(
				standard_route(1, 4, 4, 4, 2, 3, 3, 4),
				standard_route(3, 5, 5, 6, 2, 4, 4, 5),
				boss_route(1, 4, { 3, 2, 1 }, 0.74)
			), "obsidian_descent"),
			make_seed("onyx_reach", "Onyx Reach", 86477, medals(
				{ bronze = 224, silver = 199, gold = 174, black_flame = 156 },
				{ bronze = 251, silver = 221, gold = 196, black_flame = 176 },
				{ bronze = 282, silver = 250, gold = 223, black_flame = 201 }
			), route_manifest(
				standard_route(4, 5, 3, 4, 3, 3, 2, 4),
				standard_route(2, 4, 5, 5, 4, 5, 5, 4),
				boss_route(2, 3, { 1, 2, 3 }, 0.72)
			), "obsidian_descent"),
			make_seed("grave_spark", "Grave Spark", 97313, medals(
				{ bronze = 231, silver = 205, gold = 180, black_flame = 161 },
				{ bronze = 258, silver = 228, gold = 203, black_flame = 182 },
				{ bronze = 289, silver = 257, gold = 230, black_flame = 207 }
			), route_manifest(
				standard_route(3, 4, 2, 4, 2, 2, 4, 4),
				standard_route(1, 6, 4, 6, 3, 4, 4, 5),
				boss_route(3, 1, { 2, 1, 3 }, 0.77)
			), "obsidian_descent"),
		},
	},
}

local function get_pack_or_default(pack_id)
	return packs[pack_id] or packs.black_flame_circuit
end

local function sanitize_split(split, pack_version)
	return {
		id = split.id,
		label = split.label,
		floor = split.floor,
		time = split.time,
		delta = split.delta,
		gold = split.gold == true,
		pack_version = split.pack_version or pack_version or "",
	}
end

local function ordered_split_ids()
	local ids = {}
	for _, split in ipairs(split_plan) do
		ids[#ids + 1] = split.id
	end
	return ids
end

local function split_index(splits)
	local indexed = {}
	for _, split in ipairs(splits or {}) do
		indexed[split.id] = split
	end
	return indexed
end

local function ordered_splits(splits)
	local indexed = split_index(splits)
	local ordered = {}
	for _, info in ipairs(split_plan) do
		if indexed[info.id] then
			ordered[#ordered + 1] = sanitize_split(indexed[info.id])
		end
	end
	return ordered
end

local function infer_best_time_pack_version(record)
	return record.best_time_pack_version or record.pack_version or ""
end

local function infer_split_pack_version(split, record)
	if split.pack_version and split.pack_version ~= "" then
		return split.pack_version
	end
	return infer_best_time_pack_version(record)
end

local function normalize_record(record)
	if not record then
		return nil
	end
	record = util.deepcopy(record)
	record.best_time_pack_version = infer_best_time_pack_version(record)
	record.best_time_build_id = record.best_time_build_id or ""
	record.pack_version = record.best_time_pack_version ~= "" and record.best_time_pack_version or (record.pack_version or "")
	local versions = {}
	for index, split in ipairs(record.best_splits or {}) do
		record.best_splits[index] = sanitize_split(split, infer_split_pack_version(split, record))
		local version = record.best_splits[index].pack_version
		if version ~= "" then
			versions[version] = true
		end
	end
	local version_count = 0
	for _ in pairs(versions) do
		version_count = version_count + 1
	end
	record.mixed_split_versions = record.mixed_split_versions == true or version_count > 1
	return record
end

local function segment_rows(best_splits, current_splits)
	local best_index = split_index(best_splits)
	local current_ordered = ordered_splits(current_splits)
	local rows = {}
	local previous_current = 0
	local previous_best = 0
	for _, split in ipairs(current_ordered) do
		local best = best_index[split.id]
		local segment_time = math.max(0, (split.time or 0) - previous_current)
		local best_segment_time = best and best.time and math.max(0, best.time - previous_best) or nil
		local save = best_segment_time and math.max(0, segment_time - best_segment_time) or 0
		rows[#rows + 1] = {
			id = split.id,
			label = split.label,
			floor = split.floor,
			time = split.time,
			delta = split.delta,
			gold = split.gold == true,
			segment_time = segment_time,
			best_segment_time = best_segment_time,
			save = save,
		}
		previous_current = split.time or previous_current
		if best and best.time then
			previous_best = best.time
		end
	end
	return rows
end

function Sprint.get_default_pack_id()
	return "black_flame_circuit"
end

function Sprint.list_packs()
	local entries = {}
	for _, pack in pairs(packs) do
		entries[#entries + 1] = util.deepcopy(pack)
	end
	table.sort(entries, function(left, right)
		return left.id < right.id
	end)
	return entries
end

function Sprint.get_pack(pack_id)
	return util.deepcopy(get_pack_or_default(pack_id))
end

function Sprint.get_pack_version(pack_id)
	local pack = get_pack_or_default(pack_id)
	return pack.version or "1.1.0"
end

function Sprint.get_seed(pack_id, seed_id)
	local pack = get_pack_or_default(pack_id)
	for _, entry in ipairs(pack.seeds) do
		if entry.id == seed_id then
			return util.deepcopy(entry)
		end
	end
	return util.deepcopy(pack.seeds[1])
end

function Sprint.get_seed_by_index(pack_id, index)
	local pack = get_pack_or_default(pack_id)
	if #pack.seeds == 0 then
		return nil
	end
	index = util.clamp(index or 1, 1, #pack.seeds)
	return util.deepcopy(pack.seeds[index])
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

function Sprint.get_route_manifest(pack_id, seed_id, floor)
	local seed = Sprint.get_seed(pack_id, seed_id)
	return util.deepcopy((seed.route_manifest or {})[floor or 1] or {})
end

function Sprint.get_split_plan()
	return util.deepcopy(split_plan)
end

function Sprint.get_split_info(split_id)
	for _, info in ipairs(split_plan) do
		if info.id == split_id then
			return util.deepcopy(info)
		end
	end
	return nil
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
	local pool = floor_profiles[difficulty or "stalker"] or floor_profiles.stalker
	return util.deepcopy(pool[floor or 1] or pool[1])
end

function Sprint.list_practice_targets(pack_id, seed_id)
	local targets = {}
	for floor = 1, 3 do
		targets[#targets + 1] = {
			id = string.format("floor:%d", floor),
			label = string.format("Floor %d Start", floor),
			kind = "floor",
			floor = floor,
		}
	end
	if not seed_id or seed_id == "random" then
		return targets
	end
	local seed = Sprint.get_seed(pack_id, seed_id)
	for _, drill in ipairs(seed.drills or {}) do
		targets[#targets + 1] = {
			id = drill.id,
			label = drill.label,
			kind = "drill",
			floor = drill.floor,
			route_id = drill.route_id,
			goal = util.deepcopy(drill.goal),
		}
	end
	return targets
end

function Sprint.get_practice_target(pack_id, seed_id, target_id, difficulty)
	target_id = target_id or "floor:1"
	local floor = tonumber(target_id:match("^floor:(%d+)$"))
	if floor then
		return {
			id = target_id,
			label = string.format("Floor %d Start", floor),
			kind = "floor",
			floor = util.clamp(floor, 1, 3),
			snapshot = Sprint.get_practice_snapshot(difficulty, floor),
		}
	end
	if not seed_id or seed_id == "random" then
		return {
			id = "floor:1",
			label = "Floor 1 Start",
			kind = "floor",
			floor = 1,
			snapshot = Sprint.get_practice_snapshot(difficulty, 1),
		}
	end
	local seed = Sprint.get_seed(pack_id, seed_id)
	for _, drill in ipairs(seed.drills or {}) do
		if drill.id == target_id then
			local snapshot = Sprint.get_practice_snapshot(difficulty, drill.floor)
			for key, value in pairs(drill.snapshot or {}) do
				snapshot[key] = util.deepcopy(value)
			end
			return {
				id = drill.id,
				label = drill.label,
				kind = "drill",
				floor = drill.floor,
				route_id = drill.route_id,
				goal = util.deepcopy(drill.goal),
				snapshot = snapshot,
			}
		end
	end
	return {
		id = "floor:1",
		label = "Floor 1 Start",
		kind = "floor",
		floor = 1,
		snapshot = Sprint.get_practice_snapshot(difficulty, 1),
	}
end

function Sprint.normalize_practice_target(pack_id, seed_id, target_id)
	for _, target in ipairs(Sprint.list_practice_targets(pack_id, seed_id)) do
		if target.id == target_id then
			return target.id
		end
	end
	return "floor:1"
end

function Sprint.target_label(pack_id, seed_id, target_id)
	local target = Sprint.get_practice_target(pack_id, seed_id, target_id, "stalker")
	return target and target.label or "Floor 1 Start"
end

function Sprint.next_practice_target(pack_id, seed_id, current_id, step)
	local targets = Sprint.list_practice_targets(pack_id, seed_id)
	local index = 1
	for current_index, target in ipairs(targets) do
		if target.id == current_id then
			index = current_index
			break
		end
	end
	index = index + (step or 1)
	if index < 1 then
		index = #targets
	elseif index > #targets then
		index = 1
	end
	return targets[index].id
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

function Sprint.compute_best_possible_time(best_splits)
	local ordered = ordered_splits(best_splits)
	if #ordered == 0 then
		return nil
	end
	local total = 0
	local previous = 0
	for _, split in ipairs(ordered) do
		local segment = math.max(0, (split.time or 0) - previous)
		total = total + segment
		previous = split.time or previous
	end
	return total > 0 and total or ordered[#ordered].time
end

function Sprint.projected_finish(best_splits, current_splits, current_time)
	local best_index = split_index(best_splits)
	local current_ordered = ordered_splits(current_splits)
	local best_possible = Sprint.compute_best_possible_time(best_splits)
	if not best_possible then
		return nil
	end
	if #current_ordered == 0 then
		return best_possible, best_possible - (current_time or 0)
	end
	local last = current_ordered[#current_ordered]
	local best_for_last = best_index[last.id]
	if not best_for_last or not best_for_last.time then
		return current_time, (current_time or 0) - best_possible
	end
	local remaining = math.max(0, best_possible - best_for_last.time)
	local projected = (current_time or 0) + remaining
	return projected, projected - best_possible
end

function Sprint.compute_projected_saves(best_splits, current_splits, limit)
	local rows = segment_rows(best_splits, current_splits)
	table.sort(rows, function(left, right)
		if left.save == right.save then
			return (left.time or 0) > (right.time or 0)
		end
		return left.save > right.save
	end)
	local projected = {}
	local max_items = limit or 3
	for _, row in ipairs(rows) do
		if row.save and row.save > 0 then
			projected[#projected + 1] = {
				id = row.id,
				label = row.label,
				save = row.save,
				segment_time = row.segment_time,
				best_segment_time = row.best_segment_time,
			}
			if #projected >= max_items then
				break
			end
		end
	end
	return projected
end

function Sprint.get_split_rows(best_splits, current_splits)
	return segment_rows(best_splits, current_splits)
end

function Sprint.normalize_record(record)
	return normalize_record(record)
end

function Sprint.link_pb_replay(records, category_key, replay_file)
	records = records or {}
	if not category_key or not records[category_key] then
		return records, nil
	end
	local record = normalize_record(records[category_key])
	record.pb_replay = replay_file
	records[category_key] = record
	return records, util.deepcopy(record)
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
	local record = normalize_record(records[key] or {})
	local previous_medal = record.best_medal or record.medal
	local best_split_map = split_index(record.best_splits or {})
	local new_best_splits = false
	local gold_splits = {}

	for _, split in ipairs(summary.splits or {}) do
		local current = best_split_map[split.id]
		if not current or split.time < current.time then
			best_split_map[split.id] = sanitize_split(split, summary.pack_version or infer_best_time_pack_version(record))
			new_best_splits = true
			gold_splits[#gold_splits + 1] = split.id
		end
	end

	local best_splits = {}
	for _, info in ipairs(split_plan) do
		if best_split_map[info.id] then
			best_splits[#best_splits + 1] = best_split_map[info.id]
		end
	end

	local new_pb = record.best_time == nil or summary.duration < record.best_time
	local medal = summary.medal or Sprint.evaluate_medal(summary.sprint_seed_pack_id, summary.sprint_seed_id, summary.difficulty_id, summary.duration)
	local best_medal = previous_medal
	if medal and (not best_medal or medal_rank[medal] > medal_rank[best_medal]) then
		best_medal = medal
	end

	if new_pb then
		record.best_time = summary.duration
		record.best_time_pack_version = summary.pack_version or record.best_time_pack_version or ""
		record.best_time_build_id = summary.build_id or record.best_time_build_id or ""
	end
	record.best_splits = best_splits
	record.best_possible_time = Sprint.compute_best_possible_time(best_splits)
	record.best_medal = best_medal
	record.medal = best_medal
	record.pack_version = infer_best_time_pack_version(record)
	record.projected_saves = Sprint.compute_projected_saves(best_splits, summary.splits or {}, 3)
	local versions = {}
	for _, split in ipairs(record.best_splits or {}) do
		local version = split.pack_version or ""
		if version ~= "" then
			versions[version] = true
		end
	end
	local version_count = 0
	for _ in pairs(versions) do
		version_count = version_count + 1
	end
	record.mixed_split_versions = version_count > 1
	if replay_file then
		record.pb_replay = replay_file
	elseif new_pb then
		record.pb_replay = nil
	end
	record = normalize_record(record)
	records[key] = record

	return records, {
		eligible = true,
		updated = new_pb or new_best_splits or best_medal ~= previous_medal,
		new_pb = new_pb,
		new_best_splits = new_best_splits,
		medal = medal,
		best_medal = best_medal,
		best_possible_time = record.best_possible_time,
		record = util.deepcopy(record),
		category_key = key,
		gold_splits = gold_splits,
		projected_saves = util.deepcopy(record.projected_saves or {}),
		best_time_pack_version = record.best_time_pack_version,
		best_time_build_id = record.best_time_build_id,
		mixed_split_versions = record.mixed_split_versions == true,
	}
end

function Sprint.update_practice_record(records, summary)
	records = records or {}
	if not summary or summary.mode ~= "sprint" or summary.sprint_ruleset ~= "practice" or summary.outcome ~= "victory" or not summary.practice_target then
		return records, nil
	end
	local current = records[summary.practice_target]
	if current == nil or summary.duration < current.best_time then
		records[summary.practice_target] = {
			best_time = summary.duration,
			label = summary.practice_target_label or summary.practice_target,
		}
		return records, records[summary.practice_target]
	end
	return records, current
end

return Sprint
