local util = require("src.core.util")
local RNG = require("src.core.rng")
local Difficulty = require("src.data.difficulty")
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

local function build_standard_floor(config, rng)
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
	}

	local rooms = {}
	local main_rooms = {}
	local x_cursor = 2
	local mid_y = math.floor(config.map_height * 0.5)
	local main_count = 5 + config.floor

	for index = 1, main_count do
		local room_w = rng:int(3, 4)
		local room_h = rng:int(3, 5)
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
		x_cursor = x + room_w + rng:int(2, 3)
	end

	local branches = {}
	local attempts = 0
	while #branches < config.torch_goal + 1 and attempts < 32 do
		attempts = attempts + 1
		local base = main_rooms[rng:int(2, #main_rooms - 1)]
		local room_w = rng:int(3, 4)
		local room_h = rng:int(3, 4)
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
				meta.pickups[#meta.pickups + 1] = {
					kind = "relic",
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

	return World.build(meta)
end

local function build_boss_floor(config, rng)
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

	return World.build(meta)
end

function Generator.generate(difficulty_name, seed, floor, mutators)
	local config = Difficulty.build(difficulty_name, floor, mutators)
	local rng = RNG.new(seed + floor * 7919)
	if floor >= 3 then
		return build_boss_floor(config, rng)
	end
	return build_standard_floor(config, rng)
end

return Generator
