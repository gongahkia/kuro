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

local function mark_cell(meta, x, y, tag)
	if x < 1 or x > meta.width or y < 1 or y > meta.height then
		return
	end
	local cell = meta.cells[y][x]
	cell.walkable = true
	cell.tags = cell.tags or {}
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

local function add_room(meta, rooms, x, y, w, h, kind)
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
			mark_cell(meta, xx, yy, kind)
			room.cells[#room.cells + 1] = { x = xx, y = yy }
		end
	end

	rooms[#rooms + 1] = room
	return room
end

local function carve_corridor(meta, from, to, rng)
	local path = {}
	local cx, cy = from.x, from.y
	path[#path + 1] = { x = cx, y = cy }

	local horizontal_first = rng:chance(0.5)
	local function march_x()
		while cx ~= to.x do
			cx = cx + util.sign(to.x - cx)
			mark_cell(meta, cx, cy, "corridor")
			path[#path + 1] = { x = cx, y = cy }
		end
	end

	local function march_y()
		while cy ~= to.y do
			cy = cy + util.sign(to.y - cy)
			mark_cell(meta, cx, cy, "corridor")
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

local function pick_enemy_kind(config, rng)
	local kinds = {
		{ kind = "stalker", cost = 1 },
	}
	if config.floor >= 2 then
		kinds[#kinds + 1] = { kind = "rusher", cost = 2 }
		kinds[#kinds + 1] = { kind = "leech", cost = 2 }
	end
	local picked = kinds[rng:int(1, #kinds)]
	return picked.kind, picked.cost
end

function Generator.generate(difficulty_name, seed, floor, mutators)
	local config = Difficulty.build(difficulty_name, floor, mutators)
	local rng = RNG.new(seed + floor * 7919)
	local meta = {
		width = config.map_width,
		height = config.map_height,
		cells = make_cells(config.map_width, config.map_height),
		floor = floor,
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
	local main_count = 5 + floor

	for index = 1, main_count do
		local room_w = rng:int(3, 4)
		local room_h = rng:int(3, 5)
		local y = util.clamp(mid_y - math.floor(room_h * 0.5) + rng:int(-2, 2), 2, config.map_height - room_h - 1)
		local x = util.clamp(x_cursor, 2, config.map_width - room_w - 1)
		local kind = index == 1 and "start" or (index == main_count and "exit" or "main")
		local room = add_room(meta, rooms, x, y, room_w, room_h, kind)
		main_rooms[#main_rooms + 1] = room
		if index > 1 then
			local path = carve_corridor(meta, main_rooms[index - 1].center, room.center, rng)
			if #path > 3 and index < main_count then
				local pivot = path[math.floor(#path * 0.5)]
				local previous = path[math.max(1, math.floor(#path * 0.5) - 1)]
				meta.doors[#meta.doors + 1] = {
					a = { x = previous.x, y = previous.y },
					b = { x = pivot.x, y = pivot.y },
					style = "steel",
					auto_close = 0,
				}
			end
		end
		x_cursor = x + room_w + rng:int(2, 3)
	end

	local branches = {}
	local attempts = 0
	while #branches < config.torch_goal + 1 and attempts < 20 do
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
		local path = carve_corridor(meta, base.center, branch.center, rng)
		if #path > 3 then
			local pivot = path[math.floor(#path * 0.5)]
			local previous = path[math.max(1, math.floor(#path * 0.5) - 1)]
			meta.doors[#meta.doors + 1] = {
				a = { x = previous.x, y = previous.y },
				b = { x = pivot.x, y = pivot.y },
				style = "branch",
				auto_close = 0,
			}
		end
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
		cell = shrine_cell,
	}
	reserved[shrine_cell.x .. ":" .. shrine_cell.y] = true

	for index = 1, config.torch_goal do
		local room = candidate_rooms[((index + 1) - 1) % #candidate_rooms + 1]
		local cell = pick_room_cell(room, rng, reserved)
		meta.pickups[#meta.pickups + 1] = {
			kind = "torch",
			cell = cell,
		}
		reserved[cell.x .. ":" .. cell.y] = true
	end

	for index = 2, math.min(#candidate_rooms, 2 + math.floor(config.threat_budget * 0.5)) do
		meta.encounterNodes[#meta.encounterNodes + 1] = {
			kind = index == 2 and "lore" or "encounter",
			cell = {
				x = candidate_rooms[index].center.x,
				y = candidate_rooms[index].center.y,
			},
		}
	end

	local enemy_budget = math.max(1, config.threat_budget - 2)
	local enemy_rooms = {}
	for index = #candidate_rooms, 1, -1 do
		enemy_rooms[#enemy_rooms + 1] = candidate_rooms[index]
	end

	while enemy_budget > 0 and #enemy_rooms > 0 do
		local room = enemy_rooms[((enemy_budget - 1) % #enemy_rooms) + 1]
		local kind, cost = pick_enemy_kind(config, rng)
		local cell = pick_room_cell(room, rng, reserved)
		meta.enemies[#meta.enemies + 1] = {
			kind = kind,
			cell = cell,
			home = { x = room.center.x, y = room.center.y },
			patrol = pick_room_cell(room, rng, reserved),
			state = "idle",
			health = kind == "stalker" and 35 or 45,
			facing = 0,
		}
		reserved[cell.x .. ":" .. cell.y] = true
		enemy_budget = enemy_budget - cost
	end

	return World.build(meta)
end

return Generator
