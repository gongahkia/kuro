local Geometry = {}

Geometry.directions = {
	{ name = "north", dx = 0, dy = -1, angle = -math.pi * 0.5 },
	{ name = "east", dx = 1, dy = 0, angle = 0.0 },
	{ name = "south", dx = 0, dy = 1, angle = math.pi * 0.5 },
	{ name = "west", dx = -1, dy = 0, angle = math.pi },
}

Geometry.direction_by_name = {}
for _, direction in ipairs(Geometry.directions) do
	Geometry.direction_by_name[direction.name] = direction
end

function Geometry.cell_key(x, y)
	return string.format("%d:%d", x, y)
end

function Geometry.edge_key(ax, ay, bx, by)
	local left = Geometry.cell_key(ax, ay)
	local right = Geometry.cell_key(bx, by)
	if left < right then
		return left .. "|" .. right
	end
	return right .. "|" .. left
end

function Geometry.distance_to_segment(px, py, ax, ay, bx, by)
	local vx = bx - ax
	local vy = by - ay
	local wx = px - ax
	local wy = py - ay
	local lensq = vx * vx + vy * vy
	local t = 0
	if lensq > 0 then
		t = math.max(0, math.min(1, (wx * vx + wy * vy) / lensq))
	end
	local closest_x = ax + vx * t
	local closest_y = ay + vy * t
	local dx = px - closest_x
	local dy = py - closest_y
	return math.sqrt(dx * dx + dy * dy), closest_x, closest_y
end

function Geometry.facing_cardinal(angle)
	local tau = math.pi * 2
	angle = angle % tau
	if angle < math.pi * 0.25 or angle >= math.pi * 1.75 then
		return Geometry.direction_by_name.east
	end
	if angle < math.pi * 0.75 then
		return Geometry.direction_by_name.south
	end
	if angle < math.pi * 1.25 then
		return Geometry.direction_by_name.west
	end
	return Geometry.direction_by_name.north
end

function Geometry.sample_line(ax, ay, bx, by, callback)
	local steps = math.max(1, math.ceil(math.max(math.abs(bx - ax), math.abs(by - ay)) * 12))
	for index = 0, steps do
		local t = index / steps
		local x = ax + (bx - ax) * t
		local y = ay + (by - ay) * t
		if callback(x, y, t) == false then
			return false
		end
	end
	return true
end

return Geometry
