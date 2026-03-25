local util = require("src.core.util")
local Geometry = require("src.world.geometry")

local World = {}

local function edge_vertices(x, y, direction_name)
	local left = x - 1
	local right = x
	local top = y - 1
	local bottom = y

	if direction_name == "north" then
		return { x = left, y = top }, { x = right, y = top }
	end
	if direction_name == "east" then
		return { x = right, y = top }, { x = right, y = bottom }
	end
	if direction_name == "south" then
		return { x = right, y = bottom }, { x = left, y = bottom }
	end
	return { x = left, y = bottom }, { x = left, y = top }
end

local function attach_position(world, record)
	if not record or not record.cell then
		return
	end
	record.x = record.cell.x - 0.5
	record.y = record.cell.y - 0.5
	local sector = World.get_sector_by_cell(world, record.cell.x, record.cell.y)
	record.sector = sector and sector.id or nil
end

function World.cell_to_world(cell)
	return cell.x - 0.5, cell.y - 0.5
end

function World.world_to_cell(x, y)
	return math.floor(x) + 1, math.floor(y) + 1
end

function World.in_bounds(world, x, y)
	return x >= 1 and x <= world.width and y >= 1 and y <= world.height
end

function World.get_cell(world, x, y)
	if not World.in_bounds(world, x, y) then
		return nil
	end
	return world.cells[y][x]
end

function World.get_cell_tags(world, x, y)
	local cell = World.get_cell(world, x, y)
	return cell and cell.tags or nil
end

function World.cell_has_tag(world, x, y, tag)
	local tags = World.get_cell_tags(world, x, y)
	return tags ~= nil and tags[tag] == true
end

function World.is_walkable(world, x, y)
	local cell = World.get_cell(world, x, y)
	return cell ~= nil and cell.walkable == true
end

function World.get_sector_by_cell(world, x, y)
	if not World.in_bounds(world, x, y) then
		return nil
	end
	local id = world.sector_grid[y][x]
	return id and world.sectors[id] or nil
end

function World.get_sector_at(world, x, y)
	local cell_x, cell_y = World.world_to_cell(x, y)
	return World.get_sector_by_cell(world, cell_x, cell_y), cell_x, cell_y
end

function World.get_door_between(world, ax, ay, bx, by)
	local id = world.door_by_edge[Geometry.edge_key(ax, ay, bx, by)]
	return id and world.doors[id] or nil
end

function World.is_door_open(world, door_or_id)
	local door = type(door_or_id) == "table" and door_or_id or world.doors[door_or_id]
	if not door then
		return true
	end
	return door.progress >= 0.98
end

function World.is_edge_passable(world, ax, ay, bx, by, allow_closed_doors)
	if not World.is_walkable(world, bx, by) then
		return false
	end
	local door = World.get_door_between(world, ax, ay, bx, by)
	if not door then
		return true
	end
	return allow_closed_doors or World.is_door_open(world, door)
end

function World.neighbors(world, x, y, options)
	options = options or {}
	local results = {}
	for _, direction in ipairs(Geometry.directions) do
		local nx = x + direction.dx
		local ny = y + direction.dy
		if World.is_edge_passable(world, x, y, nx, ny, options.allow_closed_doors) then
			results[#results + 1] = {
				x = nx,
				y = ny,
				direction = direction,
			}
		end
	end
	return results
end

function World.find_path(world, start_cell, goal_cell, allow_closed_doors)
	if not start_cell or not goal_cell then
		return nil
	end

	local start_key = Geometry.cell_key(start_cell.x, start_cell.y)
	local goal_key = Geometry.cell_key(goal_cell.x, goal_cell.y)
	local queue = { start_cell }
	local head = 1
	local parents = {
		[start_key] = false,
	}
	local cells = {
		[start_key] = { x = start_cell.x, y = start_cell.y },
	}

	while head <= #queue do
		local current = queue[head]
		head = head + 1
		local current_key = Geometry.cell_key(current.x, current.y)
		if current_key == goal_key then
			break
		end

		for _, next in ipairs(World.neighbors(world, current.x, current.y, { allow_closed_doors = allow_closed_doors })) do
			local next_key = Geometry.cell_key(next.x, next.y)
			if parents[next_key] == nil then
				parents[next_key] = current_key
				cells[next_key] = { x = next.x, y = next.y }
				queue[#queue + 1] = { x = next.x, y = next.y }
			end
		end
	end

	if parents[goal_key] == nil then
		return nil
	end

	local path = {}
	local cursor = goal_key
	while cursor do
		table.insert(path, 1, cells[cursor])
		cursor = parents[cursor]
	end
	return path
end

function World.reachable_cells(world, start_cell)
	local queue = { start_cell }
	local head = 1
	local seen = {
		[Geometry.cell_key(start_cell.x, start_cell.y)] = true,
	}

	while head <= #queue do
		local current = queue[head]
		head = head + 1
		for _, next in ipairs(World.neighbors(world, current.x, current.y, { allow_closed_doors = true })) do
			local key = Geometry.cell_key(next.x, next.y)
			if not seen[key] then
				seen[key] = true
				queue[#queue + 1] = { x = next.x, y = next.y }
			end
		end
	end

	return seen
end

function World.has_line_of_sight(world, ax, ay, bx, by)
	local previous_x, previous_y = World.world_to_cell(ax, ay)
	return Geometry.sample_line(ax, ay, bx, by, function(sample_x, sample_y, t)
		if t == 0 then
			return true
		end
		local cell_x, cell_y = World.world_to_cell(sample_x, sample_y)
		if not World.is_walkable(world, cell_x, cell_y) then
			return false
		end
		if cell_x ~= previous_x or cell_y ~= previous_y then
			if not World.is_edge_passable(world, previous_x, previous_y, cell_x, cell_y, false) then
				return false
			end
			previous_x, previous_y = cell_x, cell_y
		end
		return true
	end)
end

function World.snapshot(world)
	local rows = {}
	for y = 1, world.height do
		local row = {}
		for x = 1, world.width do
			local cell = world.cells[y][x]
			if not cell.walkable then
				row[#row + 1] = "#"
			elseif world.exit and world.exit.cell.x == x and world.exit.cell.y == y then
				row[#row + 1] = ">"
			elseif world.spawn.cell.x == x and world.spawn.cell.y == y then
				row[#row + 1] = "@"
			else
				local symbol = "."
				for _, pickup in ipairs(world.pickups) do
					if pickup.active ~= false and pickup.cell.x == x and pickup.cell.y == y then
						symbol = pickup.kind == "torch" and "!" or "+"
					end
				end
				row[#row + 1] = symbol
			end
		end
		rows[#rows + 1] = table.concat(row)
	end
	return table.concat(rows, "\n")
end

function World.build(meta)
	local world = {
		width = meta.width,
		height = meta.height,
		cells = meta.cells,
		sectors = {},
		sector_grid = {},
		linedefs = {},
		doors = {},
		door_by_edge = {},
		pickups = util.deepcopy(meta.pickups or {}),
		encounterNodes = util.deepcopy(meta.encounterNodes or {}),
		enemies = util.deepcopy(meta.enemies or {}),
		anchors = util.deepcopy(meta.anchors or {}),
		decorations = util.deepcopy(meta.decorations or {}),
		secret_walls = util.deepcopy(meta.secret_walls or {}),
		pillars = util.deepcopy(meta.pillars or {}),
		sanityZones = util.deepcopy(meta.sanityZones or { safe = {}, dark = {}, cursed = {} }),
		routeNodes = util.deepcopy(meta.routeNodes or {}),
		exit = meta.exit and util.deepcopy(meta.exit) or nil,
		spawn = util.deepcopy(meta.spawn),
		bossRoom = meta.bossRoom and util.deepcopy(meta.bossRoom) or nil,
		navGraph = {},
		visibilityGraph = {},
		floor = meta.floor or 1,
	}

	for _, door in ipairs(meta.doors or {}) do
		local record = util.deepcopy(door)
		record.id = record.id or (#world.doors + 1)
		record.progress = record.open and 1 or 0
		record.target = record.progress
		record.timer = 0
		world.doors[record.id] = record
		world.door_by_edge[Geometry.edge_key(record.a.x, record.a.y, record.b.x, record.b.y)] = record.id
	end

	local next_sector_id = 1
	for y = 1, world.height do
		world.sector_grid[y] = {}
		for x = 1, world.width do
			local cell = world.cells[y][x]
			if cell.walkable then
				world.sector_grid[y][x] = next_sector_id
				world.sectors[next_sector_id] = {
					id = next_sector_id,
					cell = { x = x, y = y },
					floor = cell.floor or 0.0,
					ceiling = cell.ceiling or 1.2,
					tags = util.shallow_copy(cell.tags or {}),
					walls = {},
				}
				world.navGraph[next_sector_id] = {}
				world.visibilityGraph[next_sector_id] = {}
				next_sector_id = next_sector_id + 1
			end
		end
	end

	for y = 1, world.height do
		for x = 1, world.width do
			local sector = World.get_sector_by_cell(world, x, y)
			if sector then
				for _, direction in ipairs(Geometry.directions) do
					local nx = x + direction.dx
					local ny = y + direction.dy
					local neighbor = World.get_sector_by_cell(world, nx, ny)
					local door = World.get_door_between(world, x, y, nx, ny)
					local a, b = edge_vertices(x, y, direction.name)
					local wall = {
						id = #world.linedefs + 1,
						sector = sector.id,
						dir = direction.name,
						a = a,
						b = b,
						neighbor = neighbor and neighbor.id or nil,
						door_id = door and door.id or nil,
					}
					world.linedefs[#world.linedefs + 1] = wall
					sector.walls[#sector.walls + 1] = wall
					if neighbor then
						world.navGraph[sector.id][#world.navGraph[sector.id] + 1] = neighbor.id
						world.visibilityGraph[sector.id][#world.visibilityGraph[sector.id] + 1] = neighbor.id
					end
				end
			end
		end
	end

	attach_position(world, world.spawn)
	if world.exit then
		attach_position(world, world.exit)
	end
	for _, pickup in ipairs(world.pickups) do
		pickup.active = pickup.active ~= false
		pickup.radius = pickup.radius or 0.24
		attach_position(world, pickup)
	end
	for _, node in ipairs(world.encounterNodes) do
		node.triggered = node.triggered == true
		attach_position(world, node)
	end
	for _, anchor in ipairs(world.anchors) do
		anchor.lit = anchor.lit == true
		attach_position(world, anchor)
	end
	for _, enemy in ipairs(world.enemies) do
		attach_position(world, enemy)
		if enemy.home then
			enemy.home_x = enemy.home.x - 0.5
			enemy.home_y = enemy.home.y - 0.5
		end
		if enemy.patrol then
			enemy.patrol_x = enemy.patrol.x - 0.5
			enemy.patrol_y = enemy.patrol.y - 0.5
		end
	end
	for _, decoration in ipairs(world.decorations) do
		attach_position(world, decoration)
	end
	for _, pillar in ipairs(world.pillars) do
		pillar.destroyed = pillar.destroyed == true
		attach_position(world, pillar)
	end
	for _, node in pairs(world.routeNodes) do
		if node.start then
			node.start_x, node.start_y = World.cell_to_world(node.start)
		end
		if node.finish then
			node.finish_x, node.finish_y = World.cell_to_world(node.finish)
		end
	end

	return world
end

return World
