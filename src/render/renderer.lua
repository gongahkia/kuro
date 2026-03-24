local util = require("src.core.util")
local Geometry = require("src.world.geometry")
local World = require("src.world.world")

local Renderer = {}
Renderer.__index = Renderer

local palette = {
	sky = { 0.03, 0.04, 0.06, 1.0 },
	floor = { 0.06, 0.05, 0.05, 1.0 },
	wall = { 0.22, 0.26, 0.34, 1.0 },
	door = { 0.42, 0.36, 0.24, 1.0 },
	player = { 0.95, 0.95, 0.95, 1.0 },
	torch = { 1.0, 0.74, 0.26, 1.0 },
	shrine = { 0.46, 0.95, 0.72, 1.0 },
	enemy = { 0.86, 0.23, 0.22, 1.0 },
	exit = { 0.35, 0.75, 0.95, 1.0 },
}

local function shade(color, distance, gloom)
	local fade = util.clamp(1.0 - distance * 0.08 - gloom * 0.22, 0.14, 1.0)
	return color[1] * fade, color[2] * fade, color[3] * fade, color[4]
end

local function restore_scissor(previous)
	if previous[1] then
		love.graphics.setScissor(previous[1], previous[2], previous[3], previous[4])
	else
		love.graphics.setScissor()
	end
end

function Renderer.new()
	return setmetatable({
		fov = math.rad(78),
		near = 0.05,
		max_depth = 30,
	}, Renderer)
end

function Renderer:transform(camera, x, y)
	local dx = x - camera.x
	local dy = y - camera.y
	local sin_angle = math.sin(camera.angle)
	local cos_angle = math.cos(camera.angle)
	local right_x = -sin_angle
	local right_y = cos_angle
	local forward_x = cos_angle
	local forward_y = sin_angle
	return dx * right_x + dy * right_y, dx * forward_x + dy * forward_y
end

function Renderer:clip_segment(a, b)
	if a.z < self.near and b.z < self.near then
		return nil, nil
	end
	local clipped_a = { x = a.x, z = a.z }
	local clipped_b = { x = b.x, z = b.z }
	if clipped_a.z < self.near then
		local t = (self.near - clipped_a.z) / (clipped_b.z - clipped_a.z)
		clipped_a.x = clipped_a.x + (clipped_b.x - clipped_a.x) * t
		clipped_a.z = self.near
	elseif clipped_b.z < self.near then
		local t = (self.near - clipped_b.z) / (clipped_a.z - clipped_b.z)
		clipped_b.x = clipped_b.x + (clipped_a.x - clipped_b.x) * t
		clipped_b.z = self.near
	end
	return clipped_a, clipped_b
end

function Renderer:project_point(width, x, z)
	local projection = width / (2 * math.tan(self.fov * 0.5))
	return width * 0.5 + (x / z) * projection, projection
end

function Renderer:draw_wall(camera, sector, wall, color, clip_left, clip_right, gloom)
	local width, height = love.graphics.getDimensions()
	local ax, az = self:transform(camera, wall.a.x, wall.a.y)
	local bx, bz = self:transform(camera, wall.b.x, wall.b.y)
	local start, ending = self:clip_segment({ x = ax, z = az }, { x = bx, z = bz })
	if not start or not ending then
		return nil
	end

	local screen_x1, projection = self:project_point(width, start.x, start.z)
	local screen_x2 = width * 0.5 + (ending.x / ending.z) * projection
	if screen_x1 == screen_x2 then
		return nil
	end
	if screen_x2 < screen_x1 then
		screen_x1, screen_x2 = screen_x2, screen_x1
		start, ending = ending, start
	end

	local visible_left = math.max(screen_x1, clip_left)
	local visible_right = math.min(screen_x2, clip_right)
	if visible_left >= visible_right then
		return nil
	end

	local horizon = height * 0.5
	local top1 = horizon - ((sector.ceiling - camera.height) / start.z) * projection
	local bottom1 = horizon - ((sector.floor - camera.height) / start.z) * projection
	local top2 = horizon - ((sector.ceiling - camera.height) / ending.z) * projection
	local bottom2 = horizon - ((sector.floor - camera.height) / ending.z) * projection

	local r, g, b, a = shade(color, (start.z + ending.z) * 0.5, gloom)
	love.graphics.setColor(r, g, b, a)
	love.graphics.polygon("fill",
		screen_x1, top1,
		screen_x2, top2,
		screen_x2, bottom2,
		screen_x1, bottom1
	)
	love.graphics.setColor(r * 1.15, g * 1.15, b * 1.15, 0.4)
	love.graphics.line(screen_x1, top1, screen_x2, top2)
	love.graphics.line(screen_x1, bottom1, screen_x2, bottom2)

	return {
		left = visible_left,
		right = visible_right,
	}
end

function Renderer:render_sector(camera, world, sector_id, clip_left, clip_right, visited, gloom, depth)
	if depth > self.max_depth or visited[sector_id] then
		return
	end
	visited[sector_id] = true
	local sector = world.sectors[sector_id]
	if not sector then
		return
	end

	for _, wall in ipairs(sector.walls) do
		local door = wall.door_id and world.doors[wall.door_id] or nil
		local is_open_portal = wall.neighbor and (not door or World.is_door_open(world, door))
		if is_open_portal then
			local width = love.graphics.getWidth()
			local ax, az = self:transform(camera, wall.a.x, wall.a.y)
			local bx, bz = self:transform(camera, wall.b.x, wall.b.y)
			local start, ending = self:clip_segment({ x = ax, z = az }, { x = bx, z = bz })
			if start and ending then
				local screen_x1, projection = self:project_point(width, start.x, start.z)
				local screen_x2 = width * 0.5 + (ending.x / ending.z) * projection
				local left = math.max(math.min(screen_x1, screen_x2), clip_left)
				local right = math.min(math.max(screen_x1, screen_x2), clip_right)
				if left < right then
					local previous_scissor = { love.graphics.getScissor() }
					love.graphics.setScissor(left, 0, right - left, love.graphics.getHeight())
					self:render_sector(camera, world, wall.neighbor, left, right, visited, gloom, depth + 1)
					restore_scissor(previous_scissor)
				end
			end
		else
			local color = door and palette.door or palette.wall
			self:draw_wall(camera, sector, wall, color, clip_left, clip_right, gloom)
		end
	end
end

function Renderer:renderWorld(camera, world, run_state)
	local lg = love.graphics
	local width, height = lg.getDimensions()
	local gloom = run_state.blackout_time > 0 and 1.0 or 0.0
	lg.setColor(palette.sky)
	lg.rectangle("fill", 0, 0, width, height * 0.5)
	lg.setColor(palette.floor)
	lg.rectangle("fill", 0, height * 0.5, width, height * 0.5)

	local sector = World.get_sector_at(world, camera.x, camera.y)
	if sector then
		self:render_sector(camera, world, sector.id, 0, width, {}, gloom, 0)
	end
end

function Renderer:renderSprites(camera, world, entities, run_state)
	local lg = love.graphics
	local width, height = lg.getDimensions()
	local projection = width / (2 * math.tan(self.fov * 0.5))
	local horizon = height * 0.5
	local sprites = {}

	for _, entity in ipairs(entities) do
		if entity.active ~= false then
			local screen_x, depth_x = self:transform(camera, entity.x, entity.y)
			if depth_x > self.near and World.has_line_of_sight(world, camera.x, camera.y, entity.x, entity.y) then
				sprites[#sprites + 1] = {
					entity = entity,
					camera_x = screen_x,
					depth = depth_x,
				}
			end
		end
	end

	table.sort(sprites, function(left, right)
		return left.depth > right.depth
	end)

	for _, sprite in ipairs(sprites) do
		local entity = sprite.entity
		local size = (projection * (entity.scale or 0.6)) / sprite.depth
		local screen_x = width * 0.5 + (sprite.camera_x / sprite.depth) * projection
		local bottom = horizon + (camera.height / sprite.depth) * projection
		local top = bottom - size * 1.4
		local color = palette.enemy
		if entity.kind == "torch" then
			color = palette.torch
		elseif entity.kind == "shrine" then
			color = palette.shrine
		elseif entity.kind == "exit" then
			color = palette.exit
		end
		local r, g, b, a = shade(color, sprite.depth, run_state.blackout_time > 0 and 0.75 or 0.0)
		lg.setColor(r, g, b, a)
		lg.rectangle("fill", screen_x - size * 0.5, top, size, bottom - top)
		lg.setColor(1, 1, 1, 0.12)
		lg.rectangle("line", screen_x - size * 0.5, top, size, bottom - top)
	end
end

function Renderer:renderFX(run_state)
	local lg = love.graphics
	local width, height = lg.getDimensions()
	if run_state.damage_flash > 0 then
		lg.setColor(0.8, 0.1, 0.1, util.clamp(run_state.damage_flash, 0, 0.35))
		lg.rectangle("fill", 0, 0, width, height)
	end
	if run_state.blackout_time > 0 then
		lg.setColor(0.0, 0.0, 0.0, util.clamp(run_state.blackout_time * 0.28, 0.1, 0.45))
		lg.rectangle("fill", 0, 0, width, height)
	end
	lg.setColor(1.0, 1.0, 1.0, 0.5)
	lg.line(width * 0.5 - 6, height * 0.5, width * 0.5 + 6, height * 0.5)
	lg.line(width * 0.5, height * 0.5 - 6, width * 0.5, height * 0.5 + 6)
end

function Renderer:renderHUD(run_state)
	local lg = love.graphics
	local width, height = lg.getDimensions()
	local player = run_state.player
	lg.setColor(0.92, 0.94, 0.97)
	lg.print(string.format("KURO  Floor %d  %s  Seed %d", run_state.floor, run_state.difficulty_label, run_state.seed), 16, 12)
	lg.print(string.format("HP %d/%d", player.health, player.max_health), 16, 34)
	lg.print(string.format("Torches %d/%d", player.collected_torches, player.torch_goal), 16, 54)
	lg.print(string.format("Light %d%%", math.floor(player.light_charge)), 16, 74)
	lg.print(run_state.objective_text, 16, height - 68)

	local bar_x = 16
	local bar_y = 96
	local bar_w = 180
	lg.setColor(0.15, 0.15, 0.18)
	lg.rectangle("fill", bar_x, bar_y, bar_w, 12)
	lg.setColor(0.92, 0.25, 0.22)
	lg.rectangle("fill", bar_x, bar_y, bar_w * (player.health / player.max_health), 12)
	lg.setColor(0.15, 0.15, 0.18)
	lg.rectangle("fill", bar_x, bar_y + 18, bar_w, 12)
	lg.setColor(0.92, 0.74, 0.24)
	lg.rectangle("fill", bar_x, bar_y + 18, bar_w * (player.light_charge / player.max_light_charge), 12)

	local message_y = height - 48
	for index = math.max(1, #run_state.messages - 2), #run_state.messages do
		local message = run_state.messages[index]
		lg.setColor(0.74, 0.78, 0.84)
		lg.print(message, 16, message_y)
		message_y = message_y + 18
	end
end

function Renderer:draw(run_state)
	self:renderWorld(run_state.camera, run_state.world, run_state)

	local sprite_entities = {}
	for _, pickup in ipairs(run_state.world.pickups) do
		if pickup.active then
			sprite_entities[#sprite_entities + 1] = {
				kind = pickup.kind,
				x = pickup.x,
				y = pickup.y,
				scale = pickup.kind == "torch" and 0.45 or 0.6,
				active = true,
			}
		end
	end
	if run_state.world.exit then
		sprite_entities[#sprite_entities + 1] = {
			kind = "exit",
			x = run_state.world.exit.x,
			y = run_state.world.exit.y,
			scale = 0.7,
			active = true,
		}
	end
	for _, enemy in ipairs(run_state.world.enemies) do
		if enemy.alive ~= false then
			sprite_entities[#sprite_entities + 1] = {
				kind = enemy.kind,
				x = enemy.x,
				y = enemy.y,
				scale = enemy.kind == "stalker" and 0.8 or 0.9,
				active = true,
			}
		end
	end
	self:renderSprites(run_state.camera, run_state.world, sprite_entities, run_state)
	self:renderFX(run_state)
	self:renderHUD(run_state)
end

return Renderer
