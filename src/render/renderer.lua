local util = require("src.core.util")
local World = require("src.world.world")
local HUD = require("src.render.hud")
local Textures = require("src.render.textures")
local Sprites = require("src.render.sprites")

local Renderer = {}
Renderer.__index = Renderer

local palette = {
	sky = { 0.03, 0.04, 0.06, 1.0 },
	floor = { 0.06, 0.05, 0.05, 1.0 },
	wall = { 0.22, 0.26, 0.34, 1.0 },
	door = { 0.42, 0.36, 0.24, 1.0 },
	shortcut = { 0.72, 0.68, 0.26, 1.0 },
	torch = { 1.0, 0.74, 0.26, 1.0 },
	shrine = { 0.46, 0.95, 0.72, 1.0 },
	exit = { 0.35, 0.75, 0.95, 1.0 },
	stalker = { 0.86, 0.23, 0.22, 1.0 },
	rusher = { 0.95, 0.45, 0.24, 1.0 },
	leech = { 0.76, 0.88, 0.95, 1.0 },
	sentry = { 0.82, 0.52, 0.96, 1.0 },
	umbra = { 0.93, 0.2, 0.76, 1.0 },
	anchor = { 0.2, 0.9, 0.9, 1.0 },
	anchor_lit = { 1.0, 0.85, 0.42, 1.0 },
	hazard = { 0.98, 0.34, 0.2, 1.0 },
	telegraph = { 1.0, 0.18, 0.18, 1.0 },
	flare = { 1.0, 0.96, 0.55, 1.0 },
	ration = { 0.72, 0.58, 0.36, 1.0 },
	relic = { 0.95, 0.82, 0.45, 1.0 },
	calming_tonic = { 0.54, 0.92, 0.74, 1.0 },
	speed_tonic = { 0.95, 0.74, 0.24, 1.0 },
	ward_charge = { 0.72, 0.84, 1.0, 1.0 },
	note = { 0.85, 0.82, 0.72, 1.0 },
	corpse = { 0.35, 0.32, 0.30, 1.0 },
	blood_trail = { 0.55, 0.12, 0.10, 1.0 },
	pillar = { 0.66, 0.64, 0.58, 1.0 },
	blacklight = { 0.58, 0.72, 1.0, 0.42 },
	sprint_marker = { 0.82, 0.9, 0.42, 1.0 },
	minimum_marker = { 0.96, 0.92, 0.42, 1.0 },
	dark_marker = { 0.46, 0.74, 0.98, 1.0 },
	flare_marker = { 1.0, 0.78, 0.36, 1.0 },
	burn_marker = { 0.96, 0.44, 0.28, 1.0 },
	pillar_marker = { 0.82, 0.96, 0.76, 1.0 },
	ghost = { 0.3, 0.85, 0.95, 0.5 },
	bonfire = { 0.95, 0.55, 0.15, 1.0 },
	vending_machine = { 0.5, 0.6, 0.7, 1.0 },
}

local flame_palette = {
	amber = { 0.92, 0.74, 0.24, 1.0 },
	red = { 0.94, 0.38, 0.28, 1.0 },
	blue = { 0.46, 0.72, 0.98, 1.0 },
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

function Renderer.new(settings)
	local r = setmetatable({
		fov = math.rad(78),
		near = 0.05,
		max_depth = 32,
		hud = HUD.new(settings),
		textures = Textures.load(),
		sprites = Sprites.load(),
		floor_num = 1,
		time = 0,
	}, Renderer)
	r.wall_mesh = love.graphics.newMesh(4, "fan", "stream")
	return r
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
		return nil, nil, 0, 1
	end
	local clipped_a = { x = a.x, z = a.z }
	local clipped_b = { x = b.x, z = b.z }
	local t_start = 0
	local t_end = 1
	if clipped_a.z < self.near then
		local t = (self.near - a.z) / (b.z - a.z)
		clipped_a.x = a.x + (b.x - a.x) * t
		clipped_a.z = self.near
		t_start = t
	elseif clipped_b.z < self.near then
		local t = (self.near - b.z) / (a.z - b.z)
		clipped_b.x = b.x + (a.x - b.x) * t
		clipped_b.z = self.near
		t_end = 1 - t
	end
	return clipped_a, clipped_b, t_start, t_end
end

function Renderer:project_point(width, x, z)
	local projection = width / (2 * math.tan(self.fov * 0.5))
	return width * 0.5 + (x / z) * projection, projection
end

function Renderer:draw_wall(camera, sector, wall, color, texture, clip_left, clip_right, gloom)
	local width, height = love.graphics.getDimensions()
	local ax, az = self:transform(camera, wall.a.x, wall.a.y)
	local bx, bz = self:transform(camera, wall.b.x, wall.b.y)
	local start, ending, t_start, t_end = self:clip_segment({ x = ax, z = az }, { x = bx, z = bz })
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
		t_start, t_end = t_end, t_start
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

	local dist = (start.z + ending.z) * 0.5
	if texture then
		local wall_len = util.distance(wall.a.x, wall.a.y, wall.b.x, wall.b.y)
		local u1 = t_start * wall_len
		local u2 = t_end * wall_len
		local fade = util.clamp(1.0 - dist * 0.08 - gloom * 0.22, 0.14, 1.0)
		self.wall_mesh:setVertices({
			{ screen_x1, top1, u1, 0, fade, fade, fade, 1.0 },
			{ screen_x2, top2, u2, 0, fade, fade, fade, 1.0 },
			{ screen_x2, bottom2, u2, 1, fade, fade, fade, 1.0 },
			{ screen_x1, bottom1, u1, 1, fade, fade, fade, 1.0 },
		})
		self.wall_mesh:setTexture(texture)
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.draw(self.wall_mesh)
	else
		local r, g, b, a = shade(color, dist, gloom)
		love.graphics.setColor(r, g, b, a)
		love.graphics.polygon("fill",
			screen_x1, top1,
			screen_x2, top2,
			screen_x2, bottom2,
			screen_x1, bottom1
		)
	end
	local r, g, b = shade(color, dist, gloom)
	love.graphics.setColor(r * 1.18, g * 1.18, b * 1.18, 0.38)
	love.graphics.line(screen_x1, top1, screen_x2, top2)
	love.graphics.line(screen_x1, bottom1, screen_x2, bottom2)

	self:updateZbuffer(screen_x1, screen_x2, visible_left, visible_right, start.z, ending.z)

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
		visited[sector_id] = nil
		return
	end

	local wall_tex = Textures.wall_for_floor(self.textures, self.floor_num)
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
			local is_secret = door and door.secret and not World.is_door_open(world, door)
			local color = (door and not is_secret) and (door.style == "shortcut" and palette.shortcut or palette.door) or palette.wall
			local tex = wall_tex
			if door and not is_secret then
				tex = door.style == "shortcut" and self.textures.shortcut or self.textures.door
			end
			self:draw_wall(camera, sector, wall, color, tex, clip_left, clip_right, gloom)
		end
	end
	visited[sector_id] = nil -- per-branch: allow sector to render through other portals
end

function Renderer:initZbuffer(width)
	local zb = self.zbuffer
	if not zb or #zb ~= width then
		zb = {}
		self.zbuffer = zb
	end
	for x = 1, width do
		zb[x] = self.max_depth
	end
end

function Renderer:updateZbuffer(screen_x1, screen_x2, visible_left, visible_right, start_z, ending_z)
	local zb = self.zbuffer
	if not zb then return end
	local span = screen_x2 - screen_x1
	if span < 1 then return end
	local inv_z1 = 1 / start_z
	local inv_z2 = 1 / ending_z
	local col_left = math.max(1, math.floor(visible_left) + 1)
	local col_right = math.min(#zb, math.floor(visible_right))
	for x = col_left, col_right do
		local t = (x - screen_x1) / span
		local z = 1 / (inv_z1 + t * (inv_z2 - inv_z1))
		if z < zb[x] then
			zb[x] = z
		end
	end
end

function Renderer:renderWorld(camera, world, run_state)
	local lg = love.graphics
	local width, height = lg.getDimensions()
	self:initZbuffer(width)
	local gloom = run_state.blackout_time > 0 and 1.0 or 0.0
	local floor_color = palette.floor
	local sky_color = palette.sky
	local current_sector = World.get_sector_at(world, camera.x, camera.y)
	if current_sector and current_sector.tags then
		if current_sector.tags.safe_zone then
			floor_color = { 0.08, 0.09, 0.07, 1.0 }
			sky_color = { 0.05, 0.07, 0.06, 1.0 }
		elseif current_sector.tags.dark_zone then
			floor_color = { 0.03, 0.03, 0.04, 1.0 }
		elseif current_sector.tags.cursed_zone then
			floor_color = { 0.1, 0.04, 0.04, 1.0 }
			sky_color = { 0.07, 0.03, 0.04, 1.0 }
		end
	end
	lg.setColor(sky_color)
	lg.rectangle("fill", 0, 0, width, height * 0.5)
	lg.setColor(floor_color)
	lg.rectangle("fill", 0, height * 0.5, width, height * 0.5)

	local sector = current_sector
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
			local has_los = depth_x > self.near and World.has_line_of_sight(world, camera.x, camera.y, entity.x, entity.y)
			if depth_x > self.near and (has_los or entity.ignore_los) then
				sprites[#sprites + 1] = {
					entity = entity,
					camera_x = screen_x,
					depth = depth_x,
					occluded = not has_los,
				}
			end
		end
	end

	table.sort(sprites, function(left, right)
		return left.depth > right.depth
	end)

	local zb = self.zbuffer
	for _, sprite in ipairs(sprites) do
		local entity = sprite.entity
		local size = (projection * (entity.scale or 0.6)) / sprite.depth
		local screen_x = width * 0.5 + (sprite.camera_x / sprite.depth) * projection
		local bottom = horizon + (camera.height / sprite.depth) * projection
		local top = bottom - size * 1.4
		local color = sprite.occluded and palette.blacklight or (palette[entity.kind] or palette.stalker)
		if not sprite.occluded and (entity.kind == "flare" or entity.kind == "anchor_lit") then
			color = flame_palette[run_state.flame_color or "amber"] or flame_palette.amber
		end
		local r, g, b, a = shade(color, sprite.depth, run_state.blackout_time > 0 and 0.75 or 0.0)
		if sprite.occluded then
			a = a * (entity.occluded_alpha or 0.4)
		end
		local spr_left = math.floor(screen_x - size * 0.5)
		local spr_right = math.floor(screen_x + size * 0.5)
		local col_l = math.max(1, spr_left + 1)
		local col_r = math.min(width, spr_right)
		-- find visible spans via zbuffer
		local spans = {}
		local span_start = nil
		if zb then
			for x = col_l, col_r do
				if sprite.depth < zb[x] then
					if not span_start then span_start = x end
				else
					if span_start then
						spans[#spans + 1] = { span_start, x - 1 }
						span_start = nil
					end
				end
			end
			if span_start then spans[#spans + 1] = { span_start, col_r } end
		else
			spans[#spans + 1] = { col_l, col_r }
		end
		if #spans == 0 then goto continue end
		local sprite_data = self.sprites[entity.kind]
		local anim_name = entity.anim or "idle"
		local anim = sprite_data and sprite_data[anim_name]
		local prev_scissor = { lg.getScissor() }
		for _, span in ipairs(spans) do
			lg.setScissor(span[1] - 1, 0, span[2] - span[1] + 1, height)
			if anim then
				local quad, img, fw, fh = Sprites.get_frame(anim, self.time)
				local fade = util.clamp(1.0 - sprite.depth * 0.08 - (run_state.blackout_time > 0 and 0.75 or 0.0) * 0.22, 0.14, 1.0)
				if sprite.occluded then fade = fade * (entity.occluded_alpha or 0.4) end
				lg.setColor(fade, fade, fade, a)
				lg.draw(img, quad, screen_x - size * 0.5, top, 0, size / fw, (bottom - top) / fh)
			else
				local item_size = size * 0.35
				local cy = (top + bottom) * 0.5
				local bob = math.sin(self.time * 3.0 + sprite.depth) * item_size * 0.15
				lg.setColor(r, g, b, a * 0.3)
				lg.circle("fill", screen_x, cy + bob, item_size * 0.8)
				lg.setColor(r, g, b, a)
				lg.polygon("fill",
					screen_x, cy - item_size + bob,
					screen_x + item_size * 0.6, cy + bob,
					screen_x, cy + item_size + bob,
					screen_x - item_size * 0.6, cy + bob)
			end
		end
		restore_scissor(prev_scissor)
		::continue::
	end
end

-- renderAutomap, renderFX, renderHUD extracted to src/render/hud.lua

function Renderer:draw(run_state)
	self.floor_num = run_state.floor or 1
	self.time = love.timer.getTime()
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
	for _, anchor in ipairs(run_state.world.anchors) do
		sprite_entities[#sprite_entities + 1] = {
			kind = anchor.lit and "anchor_lit" or "anchor",
			x = anchor.x,
			y = anchor.y,
			scale = 0.55,
			active = true,
		}
	end
	for _, flare in ipairs(run_state.flares) do
		sprite_entities[#sprite_entities + 1] = {
			kind = "flare",
			x = flare.x,
			y = flare.y,
			scale = 0.45,
			active = true,
		}
	end
	for _, hazard in ipairs(run_state.hazards) do
		local hx, hy = World.cell_to_world(hazard.cell)
		sprite_entities[#sprite_entities + 1] = {
			kind = hazard.active and "hazard" or "telegraph",
			x = hx,
			y = hy,
			scale = hazard.active and 0.4 or 0.34,
			active = true,
		}
	end
	for _, enemy in ipairs(run_state.world.enemies) do
		if enemy.alive ~= false then
			sprite_entities[#sprite_entities + 1] = {
				kind = enemy.kind,
				x = enemy.x,
				y = enemy.y,
				scale = enemy.kind == "umbra" and 1.2 or 0.85,
				ignore_los = run_state.player.blacklight == true,
				occluded_alpha = 0.35,
				active = true,
				anim = Sprites.get_anim(enemy),
			}
		end
	end
	for _, pillar in ipairs(run_state.world.pillars or {}) do
		if not pillar.destroyed then
			sprite_entities[#sprite_entities + 1] = {
				kind = "pillar",
				x = pillar.x,
				y = pillar.y,
				scale = 0.65,
				active = true,
			}
		end
	end
	if run_state.world.decorations then
		for _, deco in ipairs(run_state.world.decorations) do
				sprite_entities[#sprite_entities + 1] = {
					kind = deco.kind,
					x = deco.x,
					y = deco.y,
					scale = (deco.kind == "vending_machine" or deco.kind == "bonfire") and 0.7
						or (deco.kind == "corpse" and 0.5
						or ((deco.kind == "sprint_marker" or deco.kind == "minimum_marker" or deco.kind == "dark_marker" or deco.kind == "flare_marker" or deco.kind == "burn_marker" or deco.kind == "pillar_marker") and 0.42 or 0.3)),
					active = true,
				}
			end
		end

	-- ghost silhouette
	if run_state.settings and run_state.settings.runner_show_ghost_3d ~= false then
		local marker = run_state.ghost_compare and run_state.ghost_compare.marker or nil
		if marker and marker.floor == run_state.floor then
			sprite_entities[#sprite_entities + 1] = {
				kind = "ghost",
				x = marker.x,
				y = marker.y,
				scale = 0.8,
				active = true,
				ignore_los = true,
			}
		end
	end
	self:renderSprites(run_state.camera, run_state.world, sprite_entities, run_state)
	self.hud:draw(run_state, love.graphics)
end

return Renderer
