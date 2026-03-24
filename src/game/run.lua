local util = require("src.core.util")
local RNG = require("src.core.rng")
local Difficulty = require("src.data.difficulty")
local Geometry = require("src.world.geometry")
local World = require("src.world.world")
local Generator = require("src.world.generator")
local AI = require("src.game.ai")

local Renderer

local Run = {}
Run.__index = Run

local lore_fragments = {
	"The walls remember names the same way bones remember weight.",
	"A torch can wound Umbra only when the light is offered.",
	"The sentries were pilgrims who stared into the pit too long.",
	"The black water reflects a ceiling that does not exist.",
	"Every shrine marks a place where someone almost escaped.",
}

local function cell_key(cell)
	return cell.x .. ":" .. cell.y
end

local function same_cell(left, right)
	return left and right and left.x == right.x and left.y == right.y
end

local function weapon_cone_hit(run, enemy)
	local dx = enemy.x - run.player.x
	local dy = enemy.y - run.player.y
	local distance = math.sqrt(dx * dx + dy * dy)
	if distance > 5.6 then
		return false
	end
	local angle_to_enemy = math.atan(dy, dx)
	local diff = math.abs(((angle_to_enemy - run.player.angle + math.pi) % (math.pi * 2)) - math.pi)
	return diff < math.rad(20) and World.has_line_of_sight(run.world, run.player.x, run.player.y, enemy.x, enemy.y)
end

local function cell_center(cell)
	local x, y = World.cell_to_world(cell)
	return x, y
end

function Run.new(difficulty, seed, mutators)
	local base_profile = Difficulty.build(difficulty, 1, mutators)
	local self = setmetatable({
		difficulty = difficulty,
		difficulty_label = base_profile.label,
		seed = seed,
		mutators = util.deepcopy(mutators or {}),
		total_floors = 3,
		floor = 1,
		rng = RNG.new(seed + 4049),
		keys = {},
		pending_interact = false,
		pending_flare = false,
		automap_enabled = false,
		damage_flash = 0,
		blackout_time = 0,
		alarm_time = 0,
		guidance_time = 0,
		guidance_cells = {},
		revealed = {},
		hazards = {},
		flares = {},
		messages = {},
		stats = {
			floors_cleared = 0,
			damage_taken = 0,
			torches_collected = 0,
			enemies_burned = 0,
			encounters_triggered = 0,
			anchors_lit = 0,
			flares_used = 0,
		},
		director = {
			threat_remaining = 0,
			cooldown = 0,
			lore_index = 0,
		},
		boss = {
			active = false,
			phase = 1,
			pulse_timer = 0,
			summon_timer = 0,
			wall_timer = 0,
		},
		completed = false,
		player = {
			x = 0,
			y = 0,
			angle = 0,
			height = 0.55,
			radius = 0.18,
			move_speed = 2.6,
			strafe_speed = 2.35,
			turn_speed = 2.2,
			max_health = base_profile.player_health,
			health = base_profile.player_health,
			max_light_charge = 100 + (mutators and mutators.embers and 10 or 0),
			light_charge = 100 + (mutators and mutators.embers and 10 or 0),
			collected_torches = 0,
			inventory_torches = 0,
			torch_goal = base_profile.torch_goal,
			fire_cooldown = 0,
			burst_charge = 0,
			flares = base_profile.flare_count,
		},
	}, Run)

	self:load_floor(1)
	return self
end

function Run:summary()
	return {
		seed = self.seed,
		difficulty = self.difficulty_label,
		floor = self.floor,
		stats = util.deepcopy(self.stats),
	}
end

function Run:push_message(message)
	self.messages[#self.messages + 1] = message
	if #self.messages > 8 then
		table.remove(self.messages, 1)
	end
end

function Run:load_floor(floor)
	local config = Difficulty.build(self.difficulty, floor, self.mutators)
	self.floor = floor
	self.floor_config = config
	self.world = Generator.generate(self.difficulty, self.seed, floor, self.mutators)
	self.player.x = self.world.spawn.x
	self.player.y = self.world.spawn.y
	self.player.angle = self.world.spawn.angle or 0
	self.player.collected_torches = 0
	self.player.inventory_torches = 0
	self.player.torch_goal = floor < self.total_floors and config.torch_goal or #self.world.anchors
		self.player.flares = config.flare_count
	self.player.light_charge = self.player.max_light_charge
	self.player.burst_charge = 0
	self.blackout_time = 0
	self.alarm_time = 0
	self.guidance_time = 0
	self.guidance_cells = {}
	self.revealed = {}
	self.hazards = {}
	self.flares = {}
	self.damage_flash = 0
	self.completed = false
	self.director = {
		threat_remaining = config.threat_budget,
		cooldown = 0,
		lore_index = 0,
	}
	self.boss = {
		active = false,
		phase = 1,
		pulse_timer = 4,
		summon_timer = 6,
		wall_timer = 5,
	}

	if floor == self.total_floors then
		self:push_message(string.format("Floor %d: the chamber breathes. Carry fire to %d anchors.", floor, #self.world.anchors))
	else
		self:push_message(string.format("Floor %d: collect %d torches and breach the exit.", floor, config.torch_goal))
	end
	self:reveal_nearby()
end

function Run:alarm_enemies(duration)
	self.alarm_time = math.max(self.alarm_time, duration)
	for _, enemy in ipairs(self.world.enemies) do
		if enemy.alive ~= false and enemy.kind ~= "umbra" then
			enemy.alert_time = math.max(enemy.alert_time or 0, duration)
		end
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

function Run:current_objective_cell()
	if self.floor < self.total_floors then
		local best_pickup
		local best_distance = math.huge
		for _, pickup in ipairs(self.world.pickups) do
			if pickup.active and pickup.kind == "torch" then
				local distance = util.distance(self.player.x, self.player.y, pickup.x, pickup.y)
				if distance < best_distance then
					best_distance = distance
					best_pickup = pickup.cell
				end
			end
		end
		if best_pickup then
			return { x = best_pickup.x, y = best_pickup.y }
		end
		return self.world.exit and { x = self.world.exit.cell.x, y = self.world.exit.cell.y } or nil
	end

	for _, pickup in ipairs(self.world.pickups) do
		if pickup.active and pickup.kind == "torch" then
			return { x = pickup.cell.x, y = pickup.cell.y }
		end
	end
	for _, anchor in ipairs(self.world.anchors) do
		if not anchor.lit then
			return { x = anchor.cell.x, y = anchor.cell.y }
		end
	end
	return nil
end

function Run:reveal_nearby()
	local origin_x, origin_y = World.world_to_cell(self.player.x, self.player.y)
	local radius = math.max(4, math.floor(self.floor_config.view_distance * 0.42))
	for dy = -radius, radius do
		for dx = -radius, radius do
			local x = origin_x + dx
			local y = origin_y + dy
			if World.is_walkable(self.world, x, y) then
				local wx, wy = World.cell_to_world({ x = x, y = y })
				if World.has_line_of_sight(self.world, self.player.x, self.player.y, wx, wy) then
					self.revealed[cell_key({ x = x, y = y })] = true
				end
			end
		end
	end
	for _, flare in ipairs(self.flares) do
		local flare_cell = flare.cell
		for dy = -3, 3 do
			for dx = -3, 3 do
				local x = flare_cell.x + dx
				local y = flare_cell.y + dy
				if World.is_walkable(self.world, x, y) then
					self.revealed[cell_key({ x = x, y = y })] = true
				end
			end
		end
	end
	if self.guidance_time > 0 then
		for key in pairs(self.guidance_cells) do
			self.revealed[key] = true
		end
	end
end

function Run:reveal_path_to_objective()
	local objective = self:current_objective_cell()
	if not objective then
		return
	end
	local start_x, start_y = World.world_to_cell(self.player.x, self.player.y)
	local path = World.find_path(self.world, { x = start_x, y = start_y }, objective, true)
	self.guidance_cells = {}
	if path then
		for _, cell in ipairs(path) do
			self.guidance_cells[cell_key(cell)] = true
		end
	end
	self.guidance_time = (self.mutators.echoes and 14 or 10)
	self:push_message("The torchlight bends and briefly reveals a route.")
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

	if self.keys.lshift then
		self.player.burst_charge = math.min(1.5, self.player.burst_charge + dt)
	end
end

function Run:spawn_enemy(kind, origin_cell)
	local origin_x = origin_cell and origin_cell.x or select(1, World.world_to_cell(self.player.x, self.player.y))
	local origin_y = origin_cell and origin_cell.y or select(2, World.world_to_cell(self.player.x, self.player.y))
	for radius = 1, 5 do
		for dy = -radius, radius do
			for dx = -radius, radius do
				local x = origin_x + dx
				local y = origin_y + dy
				if World.is_walkable(self.world, x, y) then
					local occupied = false
					for _, enemy in ipairs(self.world.enemies) do
						if enemy.alive ~= false then
							local cell_x, cell_y = World.world_to_cell(enemy.x, enemy.y)
							if cell_x == x and cell_y == y then
								occupied = true
								break
							end
						end
					end
					if not occupied then
						local spawn_x, spawn_y = cell_center({ x = x, y = y })
						self.world.enemies[#self.world.enemies + 1] = {
							kind = kind,
							cell = { x = x, y = y },
							home = { x = x, y = y },
							patrol = { x = origin_x, y = origin_y },
							state = "search",
							health = kind == "stalker" and 35 or 45,
							facing = 0,
							x = spawn_x,
							y = spawn_y,
							home_x = spawn_x,
							home_y = spawn_y,
							alive = true,
							alert_time = 2.5,
						}
						return true
					end
				end
			end
		end
	end
	return false
end

function Run:queue_hazard(cell, delay, duration, damage)
	self.hazards[#self.hazards + 1] = {
		cell = { x = cell.x, y = cell.y },
		delay = delay,
		duration = duration,
		damage = damage or 1,
		active = false,
		tick = 0,
	}
end

function Run:pick_encounter()
	if self.director.threat_remaining <= 0 then
		return self.rng:choice({ "torch-cache", "shrine", "revelation", "lore" })
	end
	local pool = { "ambush", "blackout", "trap", "elite" }
	if self.floor >= 2 then
		pool[#pool + 1] = "gauntlet"
	end
	if self.rng:chance(0.28) then
		pool[#pool + 1] = "torch-cache"
		pool[#pool + 1] = "revelation"
	end
	local picked = self.rng:choice(pool)
	if picked ~= "torch-cache" and picked ~= "revelation" and picked ~= "shrine" and picked ~= "lore" then
		self.director.threat_remaining = self.director.threat_remaining - 1
	end
	return picked
end

function Run:apply_encounter(node, kind)
	if kind == "lore" or node.kind == "lore" then
		self.director.lore_index = self.director.lore_index + 1
		local fragment = lore_fragments[((self.director.lore_index - 1) % #lore_fragments) + 1]
		self:push_message("Lore " .. self.director.lore_index .. ": " .. fragment)
		if self.mutators.echoes then
			self.player.flares = self.player.flares + 1
		end
		return
	end

	if kind == "torch-cache" then
		self.player.inventory_torches = self.player.inventory_torches + 1
		self.player.collected_torches = self.player.collected_torches + 1
		self.stats.torches_collected = self.stats.torches_collected + 1
		self:push_message("A hidden cache gifts you another torch.")
		return
	end
	if kind == "shrine" then
		self.player.health = math.min(self.player.max_health, self.player.health + 2)
		self.player.light_charge = self.player.max_light_charge
		self:push_message("A shrine quiets the panic in your chest.")
		return
	end
	if kind == "revelation" then
		self:reveal_path_to_objective()
		return
	end
	if kind == "ambush" then
		self:spawn_enemy("stalker", node.cell)
		self:spawn_enemy("leech", node.cell)
		self:push_message("[scratch] shapes peel out of the wall.")
		return
	end
	if kind == "blackout" then
		self.blackout_time = math.max(self.blackout_time, 5.0)
		self:spawn_enemy("sentry", node.cell)
		self:push_message("[hush] the room gutters into a deeper black.")
		return
	end
	if kind == "trap" then
		local origin_x, origin_y = node.cell.x, node.cell.y
		for dy = -1, 1 do
			for dx = -1, 1 do
				if World.is_walkable(self.world, origin_x + dx, origin_y + dy) then
					self:queue_hazard({ x = origin_x + dx, y = origin_y + dy }, 0.8, 1.5, 1)
				end
			end
		end
		self:push_message("[click] the floor memorizes your shape.")
		return
	end
	if kind == "elite" then
		self:spawn_enemy("rusher", node.cell)
		self:push_message("[thud] something heavier is running at you.")
		return
	end
	if kind == "gauntlet" then
		self:spawn_enemy("stalker", node.cell)
		self:spawn_enemy("rusher", node.cell)
		self:spawn_enemy("sentry", node.cell)
		self:push_message("[chorus] the corridor answers your steps.")
	end
end

function Run:update_encounters()
	local cell_x, cell_y = World.world_to_cell(self.player.x, self.player.y)
	for _, node in ipairs(self.world.encounterNodes) do
		if not node.triggered and node.cell.x == cell_x and node.cell.y == cell_y then
			node.triggered = true
			self.stats.encounters_triggered = self.stats.encounters_triggered + 1
			local kind = node.kind == "lore" and "lore" or self:pick_encounter()
			self:apply_encounter(node, kind)
		end
	end

	if self.floor == self.total_floors and self.world.bossRoom and not self.boss.active then
		for _, cell in ipairs(self.world.bossRoom.cells) do
			if cell.x == cell_x and cell.y == cell_y then
				self.boss.active = true
				self:push_message("[pulse] Umbra wakes and the room begins to breathe.")
				break
			end
		end
	end
end

function Run:collect_pickup(pickup)
	pickup.active = false
	if pickup.kind == "torch" then
		self.player.collected_torches = self.player.collected_torches + 1
		self.player.inventory_torches = self.player.inventory_torches + 1
		self.player.max_light_charge = math.min(180, self.player.max_light_charge + 8)
		self.player.light_charge = math.min(self.player.max_light_charge, self.player.light_charge + 24)
		self.stats.torches_collected = self.stats.torches_collected + 1
		self:push_message(string.format("Torch claimed %d / %d.", self.player.collected_torches, self.player.torch_goal))
	elseif pickup.kind == "shrine" then
		self.player.health = math.min(self.player.max_health, self.player.health + 2)
		self.player.light_charge = self.player.max_light_charge
		self:push_message("The shrine steadies your breathing and flame.")
	end
end

function Run:try_use_anchor(anchor)
	if anchor.lit then
		self:push_message("This anchor is already burning.")
		return
	end
	if self.player.inventory_torches <= 0 then
		self:push_message("The anchor rejects empty hands.")
		return
	end
	anchor.lit = true
	self.player.inventory_torches = self.player.inventory_torches - 1
	self.stats.anchors_lit = self.stats.anchors_lit + 1
	self:push_message(string.format("Anchor lit %d / %d.", self.stats.anchors_lit, #self.world.anchors))
	if self.stats.anchors_lit >= #self.world.anchors then
		self.completed = true
		self:push_message("Umbra buckles under the light. You survive the abyss.")
	end
end

function Run:interact()
	local cell_x, cell_y = World.world_to_cell(self.player.x, self.player.y)
	local current_cell = { x = cell_x, y = cell_y }
	local facing = Geometry.facing_cardinal(self.player.angle)
	local target_cell = { x = cell_x + facing.dx, y = cell_y + facing.dy }

	local door = World.get_door_between(self.world, current_cell.x, current_cell.y, target_cell.x, target_cell.y)
	if door then
		door.target = door.target < 0.5 and 1 or 0
		self:push_message(door.target > 0 and "Door winding open." or "Door sealing shut.")
		return
	end

	for _, pickup in ipairs(self.world.pickups) do
		if pickup.active and (same_cell(pickup.cell, current_cell) or same_cell(pickup.cell, target_cell)) then
			self:collect_pickup(pickup)
			return
		end
	end

	for _, anchor in ipairs(self.world.anchors) do
		if same_cell(anchor.cell, current_cell) or same_cell(anchor.cell, target_cell) then
			self:try_use_anchor(anchor)
			return
		end
	end

	if self.world.exit and (same_cell(self.world.exit.cell, current_cell) or same_cell(self.world.exit.cell, target_cell)) then
		if self.player.collected_torches >= self.player.torch_goal then
			self.stats.floors_cleared = self.stats.floors_cleared + 1
			if self.floor < self.total_floors then
				self:push_message("The stairwell yields to the torchlight.")
				self:load_floor(self.floor + 1)
			else
				self.completed = true
			end
		else
			self:push_message("The exit stays sealed. More torches remain.")
		end
	end
end

function Run:release_burst()
	local charge = self.player.burst_charge
	if charge <= 0.2 then
		self.player.burst_charge = 0
		return
	end
	local cost = 14 + charge * 22
	if self.player.light_charge < cost then
		self:push_message("Your flame is too weak for a burst.")
		self.player.burst_charge = 0
		return
	end
	self.player.light_charge = self.player.light_charge - cost
	self.player.burst_charge = 0
	self:push_message("[flare-burst] the chamber recoils from the light.")
	for _, enemy in ipairs(self.world.enemies) do
		if enemy.alive ~= false then
			local dx = enemy.x - self.player.x
			local dy = enemy.y - self.player.y
			local distance = math.sqrt(dx * dx + dy * dy)
			local angle_to_enemy = math.atan(dy, dx)
			local diff = math.abs(((angle_to_enemy - self.player.angle + math.pi) % (math.pi * 2)) - math.pi)
			if distance <= 2.6 + charge * 2.4 and diff < math.rad(46) then
				enemy.health = enemy.health - (24 + charge * 18)
				enemy.alert_time = 3.0
				if enemy.kind == "leech" then
					enemy.retreat_time = 1.6
				end
				if enemy.health <= 0 then
					enemy.alive = false
					self.stats.enemies_burned = self.stats.enemies_burned + 1
				end
			end
		end
	end
end

function Run:throw_flare()
	if self.player.flares <= 0 then
		self:push_message("No flares remain.")
		return
	end
	local facing = Geometry.facing_cardinal(self.player.angle)
	local current = { x = select(1, World.world_to_cell(self.player.x, self.player.y)), y = select(2, World.world_to_cell(self.player.x, self.player.y)) }
	local target = { x = current.x, y = current.y }
	for _ = 1, 4 do
		local next_cell = { x = target.x + facing.dx, y = target.y + facing.dy }
		if not World.is_walkable(self.world, next_cell.x, next_cell.y) then
			break
		end
		if not World.is_edge_passable(self.world, target.x, target.y, next_cell.x, next_cell.y, false) then
			break
		end
		target = next_cell
	end
	local x, y = World.cell_to_world(target)
	self.flares[#self.flares + 1] = {
		cell = target,
		x = x,
		y = y,
		ttl = 10.0,
	}
	self.player.flares = self.player.flares - 1
	self.stats.flares_used = self.stats.flares_used + 1
	self:push_message("[clink] a flare hisses into the dark.")
end

function Run:use_light(dt)
	self.player.fire_cooldown = math.max(0, self.player.fire_cooldown - dt)
	if self.keys.f and self.player.fire_cooldown <= 0 and self.player.light_charge > 4 then
		self.player.light_charge = math.max(0, self.player.light_charge - 24 * dt)
		self.player.fire_cooldown = 0.04
		for _, enemy in ipairs(self.world.enemies) do
			if enemy.alive ~= false and weapon_cone_hit(self, enemy) then
				enemy.health = enemy.health - 28 * dt
				enemy.alert_time = 2.2
				if enemy.kind == "leech" then
					enemy.retreat_time = 1.1
				end
				if enemy.health <= 0 then
					enemy.alive = false
					self.stats.enemies_burned = self.stats.enemies_burned + 1
					self:push_message(enemy.kind .. " burned away.")
				end
			end
		end
	else
		local recovery = 10 + math.min(3, self.player.inventory_torches) * 2
		if self.mutators.embers then
			recovery = recovery + 3
		end
		self.player.light_charge = math.min(self.player.max_light_charge, self.player.light_charge + recovery * dt)
	end
end

function Run:update_doors(dt)
	for _, door in pairs(self.world.doors) do
		door.progress = util.approach(door.progress, door.target, dt * 1.9)
	end
end

function Run:update_flares(dt)
	for index = #self.flares, 1, -1 do
		local flare = self.flares[index]
		flare.ttl = flare.ttl - dt
		if flare.ttl <= 0 then
			table.remove(self.flares, index)
		end
	end
end

function Run:update_hazards(dt)
	local player_cell = { x = select(1, World.world_to_cell(self.player.x, self.player.y)), y = select(2, World.world_to_cell(self.player.x, self.player.y)) }
	for index = #self.hazards, 1, -1 do
		local hazard = self.hazards[index]
		if not hazard.active then
			hazard.delay = hazard.delay - dt
			if hazard.delay <= 0 then
				hazard.active = true
				hazard.tick = 0
			end
		else
			hazard.duration = hazard.duration - dt
			hazard.tick = hazard.tick - dt
			if same_cell(hazard.cell, player_cell) and hazard.tick <= 0 then
				self:damage_player(hazard.damage, "The marked ground erupts under your feet.")
				hazard.tick = 0.45
			end
			if hazard.duration <= 0 then
				table.remove(self.hazards, index)
			end
		end
	end
end

function Run:update_boss(dt)
	if self.floor ~= self.total_floors or not self.boss.active or self.completed then
		return
	end

	if self.stats.anchors_lit >= math.max(2, #self.world.anchors - 1) then
		self.boss.phase = 3
	elseif self.stats.anchors_lit >= 1 then
		self.boss.phase = 2
	else
		self.boss.phase = 1
	end

	self.boss.pulse_timer = self.boss.pulse_timer - dt
	self.boss.summon_timer = self.boss.summon_timer - dt
	self.boss.wall_timer = self.boss.wall_timer - dt

	local player_cell = { x = select(1, World.world_to_cell(self.player.x, self.player.y)), y = select(2, World.world_to_cell(self.player.x, self.player.y)) }
	if self.boss.pulse_timer <= 0 then
		for _, offset in ipairs({
			{ x = 0, y = 0 },
			{ x = 1, y = 0 },
			{ x = -1, y = 0 },
			{ x = 0, y = 1 },
			{ x = 0, y = -1 },
		}) do
			local cell = { x = player_cell.x + offset.x, y = player_cell.y + offset.y }
			if World.is_walkable(self.world, cell.x, cell.y) then
				self:queue_hazard(cell, 0.85, 1.4, 1)
			end
		end
		self.blackout_time = math.max(self.blackout_time, 1.0 + self.boss.phase * 0.4)
		self.boss.pulse_timer = math.max(1.6, 4.3 - self.boss.phase)
		self:push_message("[pulse] Umbra exhales through the room.")
	end

	if self.boss.phase >= 2 and self.boss.wall_timer <= 0 then
		for _, cell in ipairs(self.world.bossRoom.cells) do
			if cell.x == player_cell.x or (self.boss.phase >= 3 and cell.y == player_cell.y) then
				self:queue_hazard({ x = cell.x, y = cell.y }, 0.95, 1.5, 1)
			end
		end
		self.boss.wall_timer = math.max(2.1, 5.0 - self.boss.phase)
		self:push_message("[crack] the chamber folds into harsher geometry.")
	end

	if self.boss.summon_timer <= 0 then
		if self.boss.phase == 1 then
			self:spawn_enemy("stalker", self.world.bossRoom.center)
		elseif self.boss.phase == 2 then
			self:spawn_enemy("sentry", self.world.bossRoom.center)
			self:spawn_enemy("leech", self.world.bossRoom.center)
		else
			self:spawn_enemy("rusher", self.world.bossRoom.center)
			self:spawn_enemy("leech", self.world.bossRoom.center)
		end
		self.boss.summon_timer = math.max(2.0, 5.0 - self.boss.phase)
	end
end

function Run:update_enemies(dt)
	for _, enemy in ipairs(self.world.enemies) do
		if enemy.alive ~= false then
			if enemy.kind == "umbra" and not self.boss.active then
				goto continue
			end
			AI.update_enemy(self, enemy, dt)
		end
		::continue::
	end
end

function Run:update(dt)
	self.damage_flash = math.max(0, self.damage_flash - dt)
	self.blackout_time = math.max(0, self.blackout_time - dt)
	self.alarm_time = math.max(0, self.alarm_time - dt)
	self.guidance_time = math.max(0, self.guidance_time - dt)
	if self.guidance_time <= 0 then
		self.guidance_cells = {}
	end

	self:update_player(dt)
	self:update_doors(dt)
	self:update_flares(dt)
	self:use_light(dt)
	self:update_encounters()
	self:update_boss(dt)
	self:update_hazards(dt)
	self:update_enemies(dt)

	if self.pending_interact then
		self.pending_interact = false
		self:interact()
	end
	if self.pending_flare then
		self.pending_flare = false
		self:throw_flare()
	end

	self:reveal_nearby()

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
	self.objective_text = self.floor < self.total_floors
		and (self.player.collected_torches < self.player.torch_goal
			and string.format("Objective: recover %d more torches.", self.player.torch_goal - self.player.collected_torches)
			or "Objective: reach the exit.")
		or string.format("Objective: light %d remaining anchors.", #self.world.anchors - self.stats.anchors_lit)
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
	elseif key == "g" then
		self.pending_flare = true
	elseif key == "tab" then
		self.automap_enabled = not self.automap_enabled
	end
end

function Run:keyreleased(key)
	self.keys[key] = nil
	if key == "lshift" or key == "rshift" then
		self:release_burst()
	end
end

return Run
