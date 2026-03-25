local util = require("src.core.util")
local RNG = require("src.core.rng")
local Difficulty = require("src.data.difficulty")
local Consumables = require("src.data.consumables")
local Sprint = require("src.game.sprint")
local World = require("src.world.world")

local Generator = {}

local function make_cells(width, height)
	local cells = {}
	for y = 1, height do
		cells[y] = {}
		for x = 1, width do
			cells[y][x] = {
				walkable = false,
				floor = 0.0,
				ceiling = 1.2,
				tags = {},
			}
		end
	end
	return cells
end

local function mark_cell(meta, x, y, tag, ceiling)
	if x < 1 or x > meta.width or y < 1 or y > meta.height then
		return
	end
	local cell = meta.cells[y][x]
	cell.walkable = true
	cell.tags = cell.tags or {}
	cell.ceiling = ceiling or cell.ceiling or 1.2
	if tag then
		cell.tags[tag] = true
	end
end

local function room_overlaps(rooms, x, y, w, h, padding)
	padding = padding or 1
	for _, room in ipairs(rooms) do
		if x <= room.x + room.w - 1 + padding and x + w - 1 + padding >= room.x and y <= room.y + room.h - 1 + padding and y + h - 1 + padding >= room.y then
			return true
		end
	end
	return false
end

local function add_room(meta, rooms, x, y, w, h, kind, ceiling)
	local room = {
		id = #rooms + 1,
		x = x,
		y = y,
		w = w,
		h = h,
		kind = kind,
		cells = {},
		center = {
			x = x + math.floor(w * 0.5),
			y = y + math.floor(h * 0.5),
		},
	}

	for yy = y, y + h - 1 do
		for xx = x, x + w - 1 do
			mark_cell(meta, xx, yy, kind, ceiling)
			room.cells[#room.cells + 1] = { x = xx, y = yy }
		end
	end

	rooms[#rooms + 1] = room
	return room
end

local function carve_corridor(meta, from, to, rng, tag)
	local path = {}
	local cx, cy = from.x, from.y
	path[#path + 1] = { x = cx, y = cy }

	local horizontal_first = rng:chance(0.5)
	local function march_x()
		while cx ~= to.x do
			cx = cx + util.sign(to.x - cx)
			mark_cell(meta, cx, cy, tag or "corridor")
			path[#path + 1] = { x = cx, y = cy }
		end
	end

	local function march_y()
		while cy ~= to.y do
			cy = cy + util.sign(to.y - cy)
			mark_cell(meta, cx, cy, tag or "corridor")
			path[#path + 1] = { x = cx, y = cy }
		end
	end

	if horizontal_first then
		march_x()
		march_y()
	else
		march_y()
		march_x()
	end

	return path
end

local function pick_room_cell(room, rng, reserved)
	local choices = {}
	for _, cell in ipairs(room.cells) do
		local key = cell.x .. ":" .. cell.y
		if not reserved[key] then
			choices[#choices + 1] = cell
		end
	end
	if #choices == 0 then
		return room.center
	end
	return choices[rng:int(1, #choices)]
end

local function add_door_from_path(meta, path, style)
	if #path < 4 then
		return
	end
	local index = math.max(2, math.floor(#path * 0.5))
	local a = path[index - 1]
	local b = path[index]
	meta.doors[#meta.doors + 1] = {
		a = { x = a.x, y = a.y },
		b = { x = b.x, y = b.y },
		style = style or "steel",
		auto_close = 0,
	}
end

local function mark_room_zone(meta, room, kind)
	meta.sanityZones = meta.sanityZones or { safe = {}, dark = {}, cursed = {} }
	local tag = kind .. "_zone"
	local record = {
		kind = kind,
		room_id = room.id,
		center = { x = room.center.x, y = room.center.y },
		cells = {},
	}
	for _, cell in ipairs(room.cells) do
		if meta.cells[cell.y] and meta.cells[cell.y][cell.x] then
			meta.cells[cell.y][cell.x].tags[tag] = true
		end
		record.cells[#record.cells + 1] = { x = cell.x, y = cell.y }
	end
	meta.sanityZones[kind][#meta.sanityZones[kind] + 1] = record
	return record
end

local function pick_consumable_kind(rng)
	local total = 0
	for _, id in ipairs(Consumables.order) do
		total = total + (Consumables.defs[id].drop_weight or 1)
	end
	local roll = rng:int(1, total)
	local running = 0
	for _, id in ipairs(Consumables.order) do
		running = running + (Consumables.defs[id].drop_weight or 1)
		if roll <= running then
			return id
		end
	end
	return Consumables.order[1]
end

local function add_consumable_pickup(meta, reserved, room, rng)
	local cell = pick_room_cell(room, rng, reserved)
	local kind = pick_consumable_kind(rng)
	meta.pickups[#meta.pickups + 1] = {
		kind = kind,
		cell = { x = cell.x, y = cell.y },
	}
	reserved[cell.x .. ":" .. cell.y] = true
end

local function mark_path_tags(meta, path, tag)
	for _, cell in ipairs(path or {}) do
		if meta.cells[cell.y] and meta.cells[cell.y][cell.x] then
			meta.cells[cell.y][cell.x].tags[tag] = true
		end
	end
end

local route_marker_kind = {
	minimum_torch = "minimum_marker",
	dark_lane = "dark_marker",
	flare_line = "flare_marker",
	burn_lane = "burn_marker",
	pillar_route = "pillar_marker",
}

local function mark_room_tags(meta, room, tag)
	if not room then
		return
	end
	for _, cell in ipairs(room.cells or {}) do
		if meta.cells[cell.y] and meta.cells[cell.y][cell.x] then
			meta.cells[cell.y][cell.x].tags[tag] = true
		end
	end
end

local function add_route_marker(meta, cell, kind, route_id)
	if not cell then
		return
	end
	meta.decorations = meta.decorations or {}
	meta.decorations[#meta.decorations + 1] = {
		kind = route_marker_kind[kind] or "sprint_marker",
		route_id = route_id,
		cell = { x = cell.x, y = cell.y },
	}
end

local function copy_cell(cell)
	return cell and { x = cell.x, y = cell.y } or nil
end

local function sample_path_cells(path, count)
	local sampled = {}
	if not path or #path == 0 or (count or 0) <= 0 then
		return sampled
	end
	if #path == 1 then
		sampled[1] = copy_cell(path[1])
		return sampled
	end
	local seen = {}
	for index = 1, count do
		local ratio = count == 1 and 0.5 or ((index - 1) / (count - 1))
		local path_index = util.clamp(math.floor(1 + ratio * (#path - 1) + 0.5), 1, #path)
		local cell = path[path_index]
		local key = cell.x .. ":" .. cell.y
		if not seen[key] then
			seen[key] = true
			sampled[#sampled + 1] = copy_cell(cell)
		end
	end
	return sampled
end

local function mark_path_ceiling(meta, path, ceiling)
	if not ceiling then
		return
	end
	for _, cell in ipairs(path or {}) do
		if meta.cells[cell.y] and meta.cells[cell.y][cell.x] then
			meta.cells[cell.y][cell.x].ceiling = math.min(meta.cells[cell.y][cell.x].ceiling or ceiling, ceiling)
		end
	end
end

local function add_path_zone(meta, path, kind)
	meta.sanityZones = meta.sanityZones or { safe = {}, dark = {}, cursed = {} }
	local tag = kind .. "_zone"
	local record = {
		kind = kind,
		cells = {},
	}
	for _, cell in ipairs(path or {}) do
		if meta.cells[cell.y] and meta.cells[cell.y][cell.x] then
			meta.cells[cell.y][cell.x].tags[tag] = true
		end
		record.cells[#record.cells + 1] = copy_cell(cell)
	end
	meta.sanityZones[kind][#meta.sanityZones[kind] + 1] = record
	return record
end

local function add_route_node(meta, route_id, kind, start_cell, finish_cell, goal, extra)
	meta.routeNodes = meta.routeNodes or {}
	local node = {
		id = route_id,
		kind = kind,
		start = copy_cell(start_cell),
		finish = copy_cell(finish_cell),
		goal = goal or "reach",
	}
	for key, value in pairs(extra or {}) do
		node[key] = util.deepcopy(value)
	end
	meta.routeNodes[route_id] = node
end

local function add_route_path(meta, route_id, kind, from_room, to_room, rng, options)
	if not from_room or not to_room then
		return nil
	end
	options = options or {}
	local path = carve_corridor(meta, from_room.center, to_room.center, rng, "shortcut")
	if #path < 4 then
		return nil
	end
	local start_cell = path[util.clamp(options.start_index or math.min(2, #path), 1, #path)] or path[1]
	local finish_cell = path[util.clamp(options.finish_index or #path, 1, #path)] or path[#path]
	add_door_from_path(meta, path, options.style or "shortcut")
	mark_path_tags(meta, path, "shortcut")
	if options.tags then
		for _, tag in ipairs(options.tags) do
			mark_path_tags(meta, path, tag)
		end
	end
	mark_path_ceiling(meta, path, options.ceiling)
	add_route_marker(meta, start_cell, kind, route_id)
	add_route_marker(meta, finish_cell, kind, route_id)
	for _, checkpoint in ipairs(options.markers or {}) do
		add_route_marker(meta, checkpoint, kind, route_id)
	end
	local extra = util.deepcopy(options.extra or {})
	extra.path = util.deepcopy(path)
	add_route_node(meta, route_id, kind, start_cell, finish_cell, options.goal or "reach", extra)
	return path
end

local function find_room_pickup(meta, room, kind)
	for _, pickup in ipairs(meta.pickups or {}) do
		if pickup.kind == kind then
			for _, cell in ipairs(room.cells or {}) do
				if pickup.cell.x == cell.x and pickup.cell.y == cell.y then
					return pickup
				end
			end
		end
	end
	return nil
end

local function apply_standard_sprint_routes(meta, main_rooms, candidate_rooms, reserved, rng, pack_id, seed_id, floor)
	local manifest = Sprint.get_route_manifest(pack_id, seed_id, floor)
	if not manifest or next(manifest) == nil then
		return
	end

	local minimum = manifest.minimum_torch or {}
	local minimum_room = candidate_rooms[util.clamp(minimum.pickup_room or 1, 1, #candidate_rooms)]
	local bonus_room = candidate_rooms[util.clamp((minimum.bonus_room or minimum.bailout_room or #candidate_rooms), 1, #candidate_rooms)]
	if minimum_room then
		mark_room_tags(meta, minimum_room, "minimum_line")
		local route_id = string.format("minimum_torch_%d", floor)
		local from_room = main_rooms[util.clamp(minimum.path_from_main or math.min(#main_rooms, 2), 1, #main_rooms)]
		local pickup = find_room_pickup(meta, minimum_room, "torch")
		if pickup then
			pickup.route_role = "minimum_torch"
			pickup.route_id = route_id
			pickup.route_budget = minimum.torch_budget or 1
			add_route_marker(meta, pickup.cell, "minimum_torch", route_id)
			local bailout_cell = bonus_room and copy_cell(bonus_room.center) or nil
			add_route_node(meta, route_id, "minimum_torch", from_room and from_room.center or pickup.cell, pickup.cell, "collect_pickup", {
				torch_budget = minimum.torch_budget or 1,
				bailout = bailout_cell,
			})
			if from_room and from_room ~= minimum_room then
				local guide_path = carve_corridor(meta, from_room.center, minimum_room.center, rng, "minimum_line")
				mark_path_tags(meta, guide_path, "minimum_line")
			end
			if bonus_room and bonus_room ~= minimum_room then
				local bailout_path = carve_corridor(meta, minimum_room.center, bonus_room.center, rng, "minimum_bailout")
				mark_path_tags(meta, bailout_path, "minimum_bailout")
				add_route_marker(meta, bonus_room.center, "minimum_torch", route_id)
			end
		end
	end

	if bonus_room then
		local bonus_cell = pick_room_cell(bonus_room, rng, reserved)
		meta.pickups[#meta.pickups + 1] = {
			kind = "torch",
			cell = { x = bonus_cell.x, y = bonus_cell.y },
			route_role = "bonus_torch",
			optional = true,
			route_id = string.format("minimum_torch_%d", floor),
		}
		reserved[bonus_cell.x .. ":" .. bonus_cell.y] = true
		mark_room_tags(meta, bonus_room, "safe_bonus")
	end

	local dark_lane = manifest.dark_lane or {}
	if dark_lane then
		local bailout_room = candidate_rooms[util.clamp(dark_lane.bailout_room or #candidate_rooms, 1, #candidate_rooms)]
		local path = add_route_path(
			meta,
			string.format("dark_lane_%d", floor),
			"dark_lane",
			candidate_rooms[util.clamp(dark_lane.from_candidate or 1, 1, #candidate_rooms)],
			main_rooms[util.clamp(dark_lane.to_main or #main_rooms, 1, #main_rooms)],
			rng,
			{
				style = "dark_lane",
				tags = { "dark_lane", "dark_zone" },
				ceiling = dark_lane.visibility_ceiling or 0.96,
				extra = {
					drain_mult = dark_lane.drain_mult or 1.7,
					bailout = bailout_room and copy_cell(bailout_room.center) or nil,
				},
			}
		)
		if path then
			add_path_zone(meta, path, "dark")
			if bailout_room then
				local pivot = path[math.max(2, math.floor(#path * 0.5))]
				local bailout_path = carve_corridor(meta, pivot, bailout_room.center, rng, "dark_lane_bailout")
				mark_path_tags(meta, bailout_path, "dark_lane_bailout")
				mark_room_tags(meta, bailout_room, "safe_bonus")
				add_route_marker(meta, pivot, "dark_lane", string.format("dark_lane_%d", floor))
			end
		end
	end

	local flare_line = manifest.flare_line or {}
	if flare_line then
		local route_id = string.format("flare_line_%d", floor)
		local path = add_route_path(
			meta,
			route_id,
			"flare_line",
			main_rooms[util.clamp(flare_line.from_main or 2, 1, #main_rooms)],
			candidate_rooms[util.clamp(flare_line.to_candidate or 1, 1, #candidate_rooms)],
			rng,
			{
				style = "flare_line",
				tags = { "flare_line" },
			}
		)
		if path then
			local checkpoints = sample_path_cells(path, flare_line.checkpoint_count or 2)
			for _, checkpoint in ipairs(checkpoints) do
				if meta.cells[checkpoint.y] and meta.cells[checkpoint.y][checkpoint.x] then
					meta.cells[checkpoint.y][checkpoint.x].tags.flare_checkpoint = true
				end
				add_route_marker(meta, checkpoint, "flare_line", route_id)
			end
			add_route_node(meta, route_id, "flare_line", path[math.min(2, #path)] or path[1], path[#path], "reach", {
				path = util.deepcopy(path),
				checkpoints = checkpoints,
				boost_window = flare_line.boost_window or 1.1,
				boost_extension = flare_line.boost_extension or 0.32,
				speed_mult = flare_line.speed_mult or 1.46,
			})
		end
	end

	local burn_lane = manifest.burn_lane or {}
	if burn_lane then
		local route_id = string.format("burn_lane_%d", floor)
		local path = add_route_path(
			meta,
			route_id,
			"burn_lane",
			candidate_rooms[util.clamp(burn_lane.from_candidate or 1, 1, #candidate_rooms)],
			main_rooms[util.clamp(burn_lane.to_main or #main_rooms, 1, #main_rooms)],
			rng,
			{
				style = "burn_lane",
				tags = { "burn_lane" },
			}
		)
		if path then
			local gates = sample_path_cells(path, burn_lane.gate_count or 2)
			for _, gate in ipairs(gates) do
				if meta.cells[gate.y] and meta.cells[gate.y][gate.x] then
					meta.cells[gate.y][gate.x].tags.burn_gate = true
				end
				add_route_marker(meta, gate, "burn_lane", route_id)
			end
			add_route_node(meta, route_id, "burn_lane", path[math.min(2, #path)] or path[1], path[#path], "reach", {
				path = util.deepcopy(path),
				gate_cells = gates,
				min_charge = burn_lane.min_charge or 0.72,
				dash_extension = burn_lane.dash_extension or 0.08,
				light_refund = burn_lane.light_refund or 4,
			})
		end
	end
end

local function apply_boss_sprint_route(meta, boss_room, manifest)
	local route = manifest and manifest.pillar_route or nil
	if not route then
		return
	end
	local primary = meta.pillars[util.clamp(route.primary_pillar or 1, 1, #meta.pillars)]
	local secondary = meta.pillars[util.clamp(route.secondary_pillar or 1, 1, #meta.pillars)]
	local anchor_order = route.anchor_order or { 1, 2, 3 }

	if primary then
		primary.route_role = "pillar_route"
		primary.weaken_bonus = route.weaken_bonus or 0.6
		primary.route_priority = 1
		add_route_marker(meta, primary.cell, "pillar_route", "pillar_route_3")
	end
	if secondary then
		secondary.route_role = "pillar_route"
		secondary.weaken_bonus = math.max(0.4, (route.weaken_bonus or 0.6) - 0.18)
		secondary.route_priority = 2
		add_route_marker(meta, secondary.cell, "pillar_route", "pillar_route_3")
	end

	local first_anchor = meta.anchors[anchor_order[1] or 1]
	for priority, anchor_index in ipairs(anchor_order) do
		if meta.anchors[anchor_index] then
			meta.anchors[anchor_index].route_priority = priority
			meta.anchors[anchor_index].route_anchor = true
			meta.cells[meta.anchors[anchor_index].cell.y][meta.anchors[anchor_index].cell.x].tags.pillar_route = true
			add_route_marker(meta, meta.anchors[anchor_index].cell, "pillar_route", "pillar_route_3")
		end
	end

	if boss_room and first_anchor then
		local path = carve_corridor(meta, boss_room.center, first_anchor.cell, RNG.new((boss_room.center.x + boss_room.center.y) * 97), "pillar_route")
		mark_path_tags(meta, path, "pillar_route")
		add_route_node(meta, "pillar_route_3", "pillar_route", boss_room.center, first_anchor.cell, "pillar_anchor", {
			path = util.deepcopy(path),
			anchor_order = util.deepcopy(anchor_order),
			pillar_cells = {
				copy_cell(primary and primary.cell or nil),
				copy_cell(secondary and secondary.cell or nil),
			},
			anchor_cells = {
				copy_cell(meta.anchors[anchor_order[1] or 1] and meta.anchors[anchor_order[1] or 1].cell or nil),
				copy_cell(meta.anchors[anchor_order[2] or 1] and meta.anchors[anchor_order[2] or 1].cell or nil),
				copy_cell(meta.anchors[anchor_order[3] or 1] and meta.anchors[anchor_order[3] or 1].cell or nil),
			},
			hazard_mult = route.hazard_mult or 0.76,
			anchor_range_bonus = route.anchor_range_bonus or 0.7,
			anchor_restore = route.anchor_restore or 12,
		})
		add_route_marker(meta, first_anchor.cell, "pillar_route", "pillar_route_3")
	end
end

local function pick_enemy_kind(config, rng)
	local kinds = {
		{ kind = "stalker", cost = 1 },
		{ kind = "rusher", cost = 2 },
	}
	if config.floor >= 2 then
		kinds[#kinds + 1] = { kind = "leech", cost = 2 }
		kinds[#kinds + 1] = { kind = "sentry", cost = 2 }
	end
	local picked = kinds[rng:int(1, #kinds)]
	return picked.kind, picked.cost
end

local function spawn_enemy(meta, reserved, room, cell, kind)
	cell = cell or room.center
	meta.enemies[#meta.enemies + 1] = {
		kind = kind,
		cell = { x = cell.x, y = cell.y },
		home = { x = room.center.x, y = room.center.y },
		patrol = { x = room.cells[1].x, y = room.cells[1].y },
		state = "idle",
		health = kind == "stalker" and 35 or (kind == "umbra" and 999 or 45),
		facing = 0,
	}
	reserved[cell.x .. ":" .. cell.y] = true
end

local function build_standard_floor(config, rng, options)
	options = options or {}
	local meta = {
		width = config.map_width,
		height = config.map_height,
		cells = make_cells(config.map_width, config.map_height),
		floor = config.floor,
		doors = {},
		pickups = {},
		encounterNodes = {},
		enemies = {},
		anchors = {},
		routeNodes = {},
		sanityZones = { safe = {}, dark = {}, cursed = {} },
	}

	local rooms = {}
	local main_rooms = {}
	local x_cursor = 2
	local mid_y = math.floor(config.map_height * 0.5)
	local main_count = 5 + config.floor

	for index = 1, main_count do
		local room_w = rng:int(5, 8)
		local room_h = rng:int(5, 8)
		local y = util.clamp(mid_y - math.floor(room_h * 0.5) + rng:int(-2, 2), 2, config.map_height - room_h - 1)
		local x = util.clamp(x_cursor, 2, config.map_width - room_w - 1)
		local kind = index == 1 and "start" or (index == main_count and "exit" or "main")
		local room = add_room(meta, rooms, x, y, room_w, room_h, kind)
		main_rooms[#main_rooms + 1] = room
		if index > 1 then
			local path = carve_corridor(meta, main_rooms[index - 1].center, room.center, rng, "corridor")
			if index < main_count then
				add_door_from_path(meta, path, "steel")
			end
		end
		x_cursor = x + room_w + rng:int(2, 4)
	end

	local branches = {}
	local attempts = 0
	while #branches < config.torch_goal + 1 and attempts < 32 do
		attempts = attempts + 1
		local base = main_rooms[rng:int(2, #main_rooms - 1)]
		local room_w = rng:int(4, 6)
		local room_h = rng:int(4, 6)
		local direction = rng:chance(0.5) and -1 or 1
		local branch_x = util.clamp(base.center.x - math.floor(room_w * 0.5) + rng:int(-1, 1), 2, config.map_width - room_w - 1)
		local branch_y = direction < 0 and base.y - room_h - rng:int(2, 4) or base.y + base.h + rng:int(2, 4)
		if branch_y < 2 or branch_y + room_h > config.map_height - 1 then
			goto continue
		end
		if room_overlaps(rooms, branch_x, branch_y, room_w, room_h, 1) then
			goto continue
		end
		local branch = add_room(meta, rooms, branch_x, branch_y, room_w, room_h, "branch")
		branches[#branches + 1] = branch
		add_door_from_path(meta, carve_corridor(meta, base.center, branch.center, rng, "branch"), "branch")
		::continue::
	end

	-- skip zones: narrow shortcuts between non-adjacent rooms (require advanced movement)
	local skip_count = math.min(2, #main_rooms - 3)
	for si = 1, skip_count do
		local from_idx = rng:int(1, math.max(1, #main_rooms - 2))
		local to_idx = math.min(#main_rooms, from_idx + 2)
		if from_idx ~= to_idx then
			local from_room = main_rooms[from_idx]
			local to_room = main_rooms[to_idx]
			local path = carve_corridor(meta, from_room.center, to_room.center, rng, "skip")
			for _, cell in ipairs(path) do
				if meta.cells[cell.y] and meta.cells[cell.y][cell.x] then
					meta.cells[cell.y][cell.x].skip_zone = true
				end
			end
		end
	end

	meta.spawn = {
		cell = { x = main_rooms[1].center.x, y = main_rooms[1].center.y },
		angle = 0,
	}
	meta.exit = {
		cell = { x = main_rooms[#main_rooms].center.x, y = main_rooms[#main_rooms].center.y },
		locked = true,
	}

	local reserved = {
		[meta.spawn.cell.x .. ":" .. meta.spawn.cell.y] = true,
		[meta.exit.cell.x .. ":" .. meta.exit.cell.y] = true,
	}

	local candidate_rooms = {}
	for index = 2, #rooms - 1 do
		candidate_rooms[#candidate_rooms + 1] = rooms[index]
	end
	rng:shuffle(candidate_rooms)

	local shrine_room = candidate_rooms[1]
	local shrine_cell = pick_room_cell(shrine_room, rng, reserved)
	meta.pickups[#meta.pickups + 1] = {
		kind = "shrine",
		cell = { x = shrine_cell.x, y = shrine_cell.y },
	}
	reserved[shrine_cell.x .. ":" .. shrine_cell.y] = true
	mark_room_zone(meta, shrine_room, "safe")

	local dark_zone_count = math.min(2, math.max(1, config.floor))
	for index = 2, math.min(#candidate_rooms, 1 + dark_zone_count) do
		mark_room_zone(meta, candidate_rooms[index], "dark")
	end
	if #candidate_rooms >= 3 then
		mark_room_zone(meta, candidate_rooms[#candidate_rooms], "cursed")
	end

	for index = 1, config.torch_goal do
		local room = candidate_rooms[((index + 1) - 1) % #candidate_rooms + 1]
		local cell = pick_room_cell(room, rng, reserved)
		meta.pickups[#meta.pickups + 1] = {
			kind = "torch",
			cell = { x = cell.x, y = cell.y },
		}
		reserved[cell.x .. ":" .. cell.y] = true
	end

	local encounter_count = math.min(#candidate_rooms, 2 + math.floor(config.threat_budget * 0.5))
	for index = 2, encounter_count do
		meta.encounterNodes[#meta.encounterNodes + 1] = {
			kind = index == 2 and "lore" or "encounter",
			cell = {
				x = candidate_rooms[index].center.x,
				y = candidate_rooms[index].center.y,
			},
		}
	end

	local enemy_budget = math.max(1, config.threat_budget - 1)
	local enemy_rooms = {}
	for index = #candidate_rooms, 1, -1 do
		enemy_rooms[#enemy_rooms + 1] = candidate_rooms[index]
	end

	while enemy_budget > 0 and #enemy_rooms > 0 do
		local room = enemy_rooms[((enemy_budget - 1) % #enemy_rooms) + 1]
		local kind, cost = pick_enemy_kind(config, rng)
		local cell = pick_room_cell(room, rng, reserved)
		spawn_enemy(meta, reserved, room, cell, kind)
		enemy_budget = enemy_budget - cost
	end

	-- environmental storytelling
	meta.decorations = meta.decorations or {}
	local note_texts = {
		"They promised safety below. They lied.",
		"Day 4. The torch is dimmer. Or my eyes are failing.",
		"If you find this, do not follow the singing.",
		"The exit moved. I am sure of it.",
		"Kael went ahead. Kael did not come back.",
	}
	for _, room in ipairs(candidate_rooms) do
		if rng:chance(0.3) then -- note
			local cell = pick_room_cell(room, rng, reserved)
			meta.pickups[#meta.pickups + 1] = {
				kind = "note",
				cell = { x = cell.x, y = cell.y },
				text = note_texts[rng:int(1, #note_texts)],
			}
			reserved[cell.x .. ":" .. cell.y] = true
		end
		if rng:chance(0.15) then -- corpse
			local cell = pick_room_cell(room, rng, reserved)
			meta.decorations[#meta.decorations + 1] = {
				kind = "corpse",
				cell = { x = cell.x, y = cell.y },
				x = cell.x - 0.5,
				y = cell.y - 0.5,
			}
		end
		if rng:chance(0.25) then -- flicker tag
			local cell = pick_room_cell(room, rng, reserved)
			if cell.x >= 1 and cell.x <= meta.width and cell.y >= 1 and cell.y <= meta.height then
				meta.cells[cell.y][cell.x].tags.flicker = true
			end
		end
	end
	-- blood trails
	if rng:chance(0.4) then
		local room = candidate_rooms[rng:int(1, #candidate_rooms)]
		local start_cell = pick_room_cell(room, rng, reserved)
		for trail_i = 0, rng:int(2, 4) do
			local bx, by = start_cell.x + trail_i, start_cell.y
			if bx >= 1 and bx <= meta.width and by >= 1 and by <= meta.height and meta.cells[by][bx].walkable then
				meta.decorations[#meta.decorations + 1] = {
					kind = "blood_trail",
					cell = { x = bx, y = by },
					x = bx - 0.5,
					y = by - 0.5,
				}
			end
		end
	end

	-- bonfires: one per floor, always in a main room
	local bonfire_room = main_rooms[rng:int(2, math.max(2, #main_rooms - 1))]
	local bonfire_cell = pick_room_cell(bonfire_room, rng, reserved)
	meta.decorations[#meta.decorations + 1] = {
		kind = "bonfire",
		cell = { x = bonfire_cell.x, y = bonfire_cell.y },
		x = bonfire_cell.x - 0.5,
		y = bonfire_cell.y - 0.5,
		lit = false,
	}
	reserved[bonfire_cell.x .. ":" .. bonfire_cell.y] = true

	-- vending machines in main rooms
	local vm_count = rng:int(1, 3)
	for _ = 1, vm_count do
		local room = main_rooms[rng:int(2, math.max(2, #main_rooms - 1))]
		local cell = pick_room_cell(room, rng, reserved)
		meta.decorations[#meta.decorations + 1] = {
			kind = "vending_machine",
			cell = { x = cell.x, y = cell.y },
			x = cell.x - 0.5,
			y = cell.y - 0.5,
		}
		reserved[cell.x .. ":" .. cell.y] = true
	end

	-- ration placement (1-2 per floor)
	local ration_count = rng:int(1, 2)
	for _ = 1, ration_count do
		local room = candidate_rooms[rng:int(1, #candidate_rooms)]
		local cell = pick_room_cell(room, rng, reserved)
		meta.pickups[#meta.pickups + 1] = {
			kind = "ration",
			cell = { x = cell.x, y = cell.y },
		}
		reserved[cell.x .. ":" .. cell.y] = true
	end

	local consumable_count = 1 + (config.floor >= 2 and 1 or 0)
	for index = 1, consumable_count do
		local room = candidate_rooms[((index + config.torch_goal) - 1) % #candidate_rooms + 1]
		add_consumable_pickup(meta, reserved, room, rng)
	end

	if options.mode == "sprint" and options.sprint_seed_pack_id and options.sprint_seed_id then
		apply_standard_sprint_routes(meta, main_rooms, candidate_rooms, reserved, rng, options.sprint_seed_pack_id, options.sprint_seed_id, config.floor)
	end

	-- secret rooms (1-2 per floor, using door system)
	meta.secret_walls = meta.secret_walls or {}
	local secret_attempts = rng:int(1, 2)
	for _ = 1, secret_attempts do
		local source_room = candidate_rooms[rng:int(1, #candidate_rooms)]
		local edge_cell = nil
		local secret_cell = nil
		for _, cell in ipairs(source_room.cells) do
			for _, dir in ipairs({ { dx = 0, dy = -1 }, { dx = 0, dy = 1 }, { dx = -1, dy = 0 }, { dx = 1, dy = 0 } }) do
				local nx, ny = cell.x + dir.dx, cell.y + dir.dy
				local sx, sy = nx + dir.dx, ny + dir.dy -- cell behind the wall
				if nx >= 2 and nx < meta.width and ny >= 2 and ny < meta.height
					and sx >= 2 and sx < meta.width and sy >= 2 and sy < meta.height
					and not meta.cells[ny][nx].walkable and not meta.cells[sy][sx].walkable then
					local blocked = false
					for dy2 = -1, 1 do
						for dx2 = -1, 1 do
							local check_y, check_x = sy + dy2, sx + dx2
							if check_y >= 1 and check_y <= meta.height and check_x >= 1 and check_x <= meta.width then
								if meta.cells[check_y][check_x].walkable then blocked = true end
							end
						end
					end
					if not blocked then
						edge_cell = { x = nx, y = ny }
						secret_cell = { x = sx, y = sy }
					end
				end
			end
			if secret_cell then break end
		end
		if edge_cell and secret_cell then
			mark_cell(meta, edge_cell.x, edge_cell.y, "secret_passage")
			mark_cell(meta, secret_cell.x, secret_cell.y, "secret_room")
			local adjacent_walkable = nil -- find the walkable cell adjacent to edge_cell
			for _, dir in ipairs({ { dx = 0, dy = -1 }, { dx = 0, dy = 1 }, { dx = -1, dy = 0 }, { dx = 1, dy = 0 } }) do
				local ax, ay = edge_cell.x + dir.dx, edge_cell.y + dir.dy
				if ax ~= secret_cell.x or ay ~= secret_cell.y then
					if ax >= 1 and ax <= meta.width and ay >= 1 and ay <= meta.height and meta.cells[ay][ax].walkable then
						adjacent_walkable = { x = ax, y = ay }
						break
					end
				end
			end
			if adjacent_walkable then
				meta.doors[#meta.doors + 1] = {
					a = { x = adjacent_walkable.x, y = adjacent_walkable.y },
					b = { x = edge_cell.x, y = edge_cell.y },
					style = "secret",
					secret = true,
					auto_close = 0,
				}
				local secret_kind = rng:chance(0.5) and "relic" or pick_consumable_kind(rng)
				meta.pickups[#meta.pickups + 1] = {
					kind = secret_kind,
					cell = { x = secret_cell.x, y = secret_cell.y },
				}
				meta.secret_walls[#meta.secret_walls + 1] = {
					cell_a = adjacent_walkable,
					cell_b = edge_cell,
					reveal_method = rng:chance(0.5) and "burst" or "lore_clue",
					required_fragment = rng:chance(0.5) and rng:int(1, 6) or nil,
				}
			end
		end
	end

	-- sight line windows: transparent walls between adjacent rooms for route discovery
	meta.window_walls = {}
	for i = 1, #main_rooms - 1 do
		if rng:chance(0.4) then
			local from = main_rooms[i]
			local to = main_rooms[i + 1]
			meta.window_walls[#meta.window_walls + 1] = {
				from_room = i,
				to_room = i + 1,
				from_center = { x = from.center.x, y = from.center.y },
				to_center = { x = to.center.x, y = to.center.y },
			}
		end
	end

	return World.build(meta)
end

local function build_boss_floor(config, rng, options)
	options = options or {}
	local meta = {
		width = math.max(34, config.map_width),
		height = math.max(18, config.map_height),
		cells = make_cells(math.max(34, config.map_width), math.max(18, config.map_height)),
		floor = config.floor,
		doors = {},
		pickups = {},
		encounterNodes = {},
		enemies = {},
		anchors = {},
		routeNodes = {},
		sanityZones = { safe = {}, dark = {}, cursed = {} },
	}

	local rooms = {}
	local mid_y = math.floor(meta.height * 0.5)
	local start = add_room(meta, rooms, 2, mid_y - 2, 4, 5, "start")
	local north = add_room(meta, rooms, 8, 3, 5, 4, "branch")
	local south = add_room(meta, rooms, 8, meta.height - 6, 5, 4, "branch")
	local chapel = add_room(meta, rooms, 14, 2, 4, 4, "safe")
	local hall = add_room(meta, rooms, 7, mid_y - 1, 10, 3, "corridor")
	local ante = add_room(meta, rooms, 18, mid_y - 2, 4, 5, "ante")
	local boss = add_room(meta, rooms, 23, mid_y - 4, 8, 8, "boss", 1.5)

	add_door_from_path(meta, carve_corridor(meta, start.center, hall.center, rng, "corridor"), "steel")
	add_door_from_path(meta, carve_corridor(meta, hall.center, north.center, rng, "branch"), "branch")
	add_door_from_path(meta, carve_corridor(meta, hall.center, south.center, rng, "branch"), "branch")
	add_door_from_path(meta, carve_corridor(meta, hall.center, chapel.center, rng, "corridor"), "shrine")
	add_door_from_path(meta, carve_corridor(meta, hall.center, ante.center, rng, "corridor"), "steel")
	carve_corridor(meta, ante.center, boss.center, rng, "boss")

	meta.spawn = {
		cell = { x = start.center.x, y = start.center.y },
		angle = 0,
	}
	meta.bossRoom = {
		center = { x = boss.center.x, y = boss.center.y },
		cells = boss.cells,
	}

	local reserved = {
		[meta.spawn.cell.x .. ":" .. meta.spawn.cell.y] = true,
	}

	mark_room_zone(meta, chapel, "safe")
	mark_room_zone(meta, ante, "cursed")
	mark_room_zone(meta, boss, "dark")

	local torch_rooms = { north, south, chapel, ante, hall }
	for index = 1, config.torch_goal do
		local room = torch_rooms[((index - 1) % #torch_rooms) + 1]
		local cell = pick_room_cell(room, rng, reserved)
		meta.pickups[#meta.pickups + 1] = {
			kind = index == 1 and "shrine" or "torch",
			cell = { x = cell.x, y = cell.y },
		}
		reserved[cell.x .. ":" .. cell.y] = true
	end

	meta.anchors = {
		{ cell = { x = boss.x + 2, y = boss.y + 2 } },
		{ cell = { x = boss.x + boss.w - 2, y = boss.y + 2 } },
		{ cell = { x = boss.center.x, y = boss.y + boss.h - 2 } },
	}

	meta.encounterNodes = {
		{ kind = "lore", cell = { x = hall.center.x, y = hall.center.y } },
		{ kind = "encounter", cell = { x = north.center.x, y = north.center.y } },
		{ kind = "encounter", cell = { x = south.center.x, y = south.center.y } },
		{ kind = "encounter", cell = { x = ante.center.x, y = ante.center.y } },
	}

	spawn_enemy(meta, reserved, north, north.center, "sentry")
	spawn_enemy(meta, reserved, south, south.center, "leech")
	spawn_enemy(meta, reserved, ante, ante.center, "stalker")
	spawn_enemy(meta, reserved, boss, boss.center, "umbra")

	-- boss arena pillars (4 destructible doors in quadrants)
	meta.pillars = {}
	local pillar_offsets = {
		{ x = boss.x + 2, y = boss.y + 2 },
		{ x = boss.x + boss.w - 2, y = boss.y + 2 },
		{ x = boss.x + 2, y = boss.y + boss.h - 2 },
		{ x = boss.x + boss.w - 2, y = boss.y + boss.h - 2 },
	}
	for _, pos in ipairs(pillar_offsets) do
		if pos.x >= 1 and pos.x <= meta.width and pos.y >= 1 and pos.y <= meta.height then
			local cell = meta.cells[pos.y][pos.x]
			if cell.walkable then
				cell.tags.pillar = true
				cell.tags.destructible = true
				meta.pillars[#meta.pillars + 1] = { cell = { x = pos.x, y = pos.y }, health = 40 }
			end
		end
	end

	if options.mode == "sprint" and options.sprint_seed_pack_id and options.sprint_seed_id then
		apply_boss_sprint_route(meta, boss, Sprint.get_route_manifest(options.sprint_seed_pack_id, options.sprint_seed_id, 3))
	end

	-- fog zone tags on boss room edges
	for _, cell in ipairs(boss.cells) do
		if cell.x == boss.x + 1 or cell.x == boss.x + boss.w or cell.y == boss.y + 1 or cell.y == boss.y + boss.h then
			local c = meta.cells[cell.y][cell.x]
			if c.walkable then c.tags.fog_zone = true end
		end
	end

	-- ration in chapel
	local ration_cell = pick_room_cell(chapel, rng, reserved)
	meta.pickups[#meta.pickups + 1] = { kind = "ration", cell = { x = ration_cell.x, y = ration_cell.y } }
	reserved[ration_cell.x .. ":" .. ration_cell.y] = true
	add_consumable_pickup(meta, reserved, hall, rng)

	return World.build(meta)
end

function Generator.generate(difficulty_name, seed, floor, mutators, options)
	local config = Difficulty.build(difficulty_name, floor, mutators)
	local rng = RNG.new(seed + floor * 7919)
	if floor >= 3 then
		return build_boss_floor(config, rng, options)
	end
	return build_standard_floor(config, rng, options)
end

return Generator
