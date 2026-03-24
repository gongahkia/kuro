local util = require("src.core.util")
local Difficulty = require("src.data.difficulty")
local Geometry = require("src.world.geometry")
local World = require("src.world.world")
local Generator = require("src.world.generator")
local AI = require("src.game.ai")

local Renderer

local Run = {}
Run.__index = Run

local function weapon_cone_hit(run, enemy)
	local dx = enemy.x - run.player.x
	local dy = enemy.y - run.player.y
	local distance = math.sqrt(dx * dx + dy * dy)
	if distance > 5.2 then
		return false
	end
	local angle_to_enemy = math.atan(dy, dx)
	local diff = math.abs(((angle_to_enemy - run.player.angle + math.pi) % (math.pi * 2)) - math.pi)
	return diff < math.rad(18) and World.has_line_of_sight(run.world, run.player.x, run.player.y, enemy.x, enemy.y)
end

function Run.new(difficulty, seed)
	local profile = Difficulty.build(difficulty, 1, nil)
	local self = setmetatable({
		difficulty = difficulty,
		difficulty_label = profile.label,
		seed = seed,
		floor = 1,
		keys = {},
		pending_interact = false,
		world = Generator.generate(difficulty, seed, 1, nil),
		player = {
			x = 0,
			y = 0,
			angle = 0,
			height = 0.55,
			radius = 0.18,
			move_speed = 2.6,
			strafe_speed = 2.35,
			turn_speed = 2.2,
			max_health = profile.player_health,
			health = profile.player_health,
			max_light_charge = 100,
			light_charge = 100,
			collected_torches = 0,
			torch_goal = profile.torch_goal,
			fire_cooldown = 0,
		},
		damage_flash = 0,
		blackout_time = 0,
		alarm_time = 0,
		messages = {},
		stats = {
			damage_taken = 0,
			torches_collected = 0,
			enemies_burned = 0,
		},
		completed = false,
	}, Run)

	self.player.x = self.world.spawn.x
	self.player.y = self.world.spawn.y
	self.player.angle = self.world.spawn.angle or 0
	self:push_message("Recovered the torchlight. Find every ember on the floor.")
	return self
end

function Run:push_message(message)
	self.messages[#self.messages + 1] = message
	if #self.messages > 6 then
		table.remove(self.messages, 1)
	end
end

function Run:damage_player(amount, reason)
	self.player.health = math.max(0, self.player.health - amount)
	self.damage_flash = 0.32
	self.stats.damage_taken = self.stats.damage_taken + amount
	if reason then
		self:push_message(reason)
	end
end

function Run:attempt_axis(candidate_x, candidate_y)
	local candidate_cell_x, candidate_cell_y = World.world_to_cell(candidate_x, candidate_y)
	if not World.is_walkable(self.world, candidate_cell_x, candidate_cell_y) then
		return false
	end

	local position = { x = candidate_x, y = candidate_y }
	for y = candidate_cell_y - 1, candidate_cell_y + 1 do
		for x = candidate_cell_x - 1, candidate_cell_x + 1 do
			local sector = World.get_sector_by_cell(self.world, x, y)
			if sector then
				for _, wall in ipairs(sector.walls) do
					local blocking = wall.neighbor == nil or (wall.door_id and not World.is_door_open(self.world, wall.door_id))
					if blocking then
						local distance, closest_x, closest_y = Geometry.distance_to_segment(position.x, position.y, wall.a.x, wall.a.y, wall.b.x, wall.b.y)
						if distance < self.player.radius then
							local push_x, push_y, push_distance = util.normalize(position.x - closest_x, position.y - closest_y)
							if push_distance == 0 then
								local facing = Geometry.direction_by_name[wall.dir]
								push_x = -facing.dy
								push_y = facing.dx
							end
							local correction = self.player.radius - distance
							position.x = position.x + push_x * correction
							position.y = position.y + push_y * correction
						end
					end
				end
			end
		end
	end

	self.player.x = position.x
	self.player.y = position.y
	return true
end

function Run:update_player(dt)
	local move = 0
	local strafe = 0
	local turn = 0

	if self.keys.w then
		move = move + 1
	end
	if self.keys.s then
		move = move - 1
	end
	if self.keys.q then
		strafe = strafe - 1
	end
	if self.keys.e then
		strafe = strafe + 1
	end
	if self.keys.a then
		turn = turn - 1
	end
	if self.keys.d then
		turn = turn + 1
	end

	self.player.angle = util.wrap_angle(self.player.angle + turn * self.player.turn_speed * dt)

	local forward_x = math.cos(self.player.angle)
	local forward_y = math.sin(self.player.angle)
	local right_x = -math.sin(self.player.angle)
	local right_y = math.cos(self.player.angle)

	local vx = forward_x * move * self.player.move_speed + right_x * strafe * self.player.strafe_speed
	local vy = forward_y * move * self.player.move_speed + right_y * strafe * self.player.strafe_speed
	local nx, ny, length = util.normalize(vx, vy)
	if length > 0 then
		vx = nx * math.max(self.player.move_speed, self.player.strafe_speed)
		vy = ny * math.max(self.player.move_speed, self.player.strafe_speed)
	end

	self:attempt_axis(self.player.x + vx * dt, self.player.y)
	self:attempt_axis(self.player.x, self.player.y + vy * dt)
end

function Run:use_light(dt)
	self.player.fire_cooldown = math.max(0, self.player.fire_cooldown - dt)
	if self.keys.f and self.player.fire_cooldown <= 0 and self.player.light_charge > 6 then
		self.player.light_charge = math.max(0, self.player.light_charge - 18 * dt)
		self.player.fire_cooldown = 0.04
		for _, enemy in ipairs(self.world.enemies) do
			if enemy.alive ~= false and weapon_cone_hit(self, enemy) then
				enemy.health = enemy.health - 22 * dt
				enemy.alert_time = 2.0
				if enemy.health <= 0 then
					enemy.alive = false
					self.stats.enemies_burned = self.stats.enemies_burned + 1
					self:push_message(enemy.kind .. " burned away.")
				end
			end
		end
	else
		self.player.light_charge = math.min(self.player.max_light_charge, self.player.light_charge + 12 * dt)
	end
end

function Run:interact()
	local cell_x, cell_y = World.world_to_cell(self.player.x, self.player.y)
	local facing = Geometry.facing_cardinal(self.player.angle)
	local target_x = cell_x + facing.dx
	local target_y = cell_y + facing.dy

	local door = World.get_door_between(self.world, cell_x, cell_y, target_x, target_y)
	if door then
		door.target = door.target < 0.5 and 1 or 0
		self:push_message(door.target > 0 and "Door winding open." or "Door sealing shut.")
		return
	end

	for _, pickup in ipairs(self.world.pickups) do
		if pickup.active and ((pickup.cell.x == cell_x and pickup.cell.y == cell_y) or (pickup.cell.x == target_x and pickup.cell.y == target_y)) then
			pickup.active = false
			if pickup.kind == "torch" then
				self.player.collected_torches = self.player.collected_torches + 1
				self.player.max_light_charge = math.min(160, self.player.max_light_charge + 8)
				self.player.light_charge = math.min(self.player.max_light_charge, self.player.light_charge + 20)
				self.stats.torches_collected = self.stats.torches_collected + 1
				self:push_message(string.format("Torch claimed %d / %d.", self.player.collected_torches, self.player.torch_goal))
			elseif pickup.kind == "shrine" then
				self.player.health = math.min(self.player.max_health, self.player.health + 2)
				self.player.light_charge = self.player.max_light_charge
				self:push_message("The shrine steadies your breathing and flame.")
			end
			return
		end
	end

	if self.world.exit then
		local on_exit = (self.world.exit.cell.x == cell_x and self.world.exit.cell.y == cell_y) or (self.world.exit.cell.x == target_x and self.world.exit.cell.y == target_y)
		if on_exit then
			if self.player.collected_torches >= self.player.torch_goal then
				self:push_message("The gate yields. The prototype slice is complete.")
				self.completed = true
			else
				self:push_message("The exit stays sealed. More torches remain.")
			end
		end
	end
end

function Run:update_doors(dt)
	for _, door in pairs(self.world.doors) do
		door.progress = util.approach(door.progress, door.target, dt * 1.9)
	end
end

function Run:update_enemies(dt)
	for _, enemy in ipairs(self.world.enemies) do
		if enemy.alive ~= false then
			AI.update_enemy(self, enemy, dt)
		end
	end
end

function Run:update(dt)
	self.damage_flash = math.max(0, self.damage_flash - dt)
	self.blackout_time = math.max(0, self.blackout_time - dt)
	self.alarm_time = math.max(0, self.alarm_time - dt)

	self:update_player(dt)
	self:update_doors(dt)
	self:use_light(dt)
	self:update_enemies(dt)

	if self.pending_interact then
		self.pending_interact = false
		self:interact()
	end

	if self.player.health <= 0 then
		return "dead"
	end
	if self.completed then
		return "victory"
	end
	return nil
end

function Run:draw()
	if not Renderer then
		Renderer = require("src.render.renderer")
	end
	self.renderer = self.renderer or Renderer.new()
	self.objective_text = self.player.collected_torches < self.player.torch_goal
		and string.format("Objective: recover %d more torches.", self.player.torch_goal - self.player.collected_torches)
		or "Objective: reach the exit."
	self.camera = {
		x = self.player.x,
		y = self.player.y,
		angle = self.player.angle,
		height = self.player.height,
	}
	self.renderer:draw(self)
end

function Run:keypressed(key)
	self.keys[key] = true
	if key == "space" then
		self.pending_interact = true
	end
end

function Run:keyreleased(key)
	self.keys[key] = nil
end

return Run
