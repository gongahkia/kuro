local util = require("src.core.util")
local Geometry = require("src.world.geometry")
local World = require("src.world.world")

local AI = {}

local archetypes = {
	stalker = {
		speed = 1.35,
		damage = 1,
		range = 7.0,
		attack_cooldown = 0.85,
		light_vulnerability = 1.0,
	},
	rusher = {
		speed = 1.45,
		damage = 2,
		range = 8.0,
		attack_cooldown = 1.0,
		light_vulnerability = 0.9,
	},
	leech = {
		speed = 1.5,
		damage = 1,
		range = 6.0,
		attack_cooldown = 1.0,
		light_vulnerability = 1.2,
	},
}

function AI.describe(enemy, context)
	local spec = archetypes[enemy.kind] or archetypes.stalker
	local distance = util.distance(enemy.x, enemy.y, context.player.x, context.player.y)
	local visible = distance <= spec.range and World.has_line_of_sight(context.world, enemy.x, enemy.y, context.player.x, context.player.y)

	if enemy.kind == "leech" and enemy.retreat_time and enemy.retreat_time > 0 then
		return "retreat", visible
	end
	if visible or (enemy.alert_time and enemy.alert_time > 0) or context.alarm_time > 0 then
		return "chase", visible
	end
	if enemy.search_time and enemy.search_time > 0 then
		return "search", false
	end
	return "idle", false
end

local function move_toward(enemy, target_x, target_y, speed, dt)
	local nx, ny, distance = util.normalize(target_x - enemy.x, target_y - enemy.y)
	if distance == 0 then
		return
	end
	enemy.x = enemy.x + nx * speed * dt
	enemy.y = enemy.y + ny * speed * dt
	enemy.facing = math.atan(ny, nx)
end

local function move_along_cells(run, enemy, speed, dt, target_cell)
	local current_x, current_y = World.world_to_cell(enemy.x, enemy.y)
	local path = World.find_path(run.world, { x = current_x, y = current_y }, target_cell, false)
	if not path or #path < 2 then
		return
	end
	local next_cell = path[2]
	local target_x, target_y = World.cell_to_world(next_cell)
	move_toward(enemy, target_x, target_y, speed, dt)
end

function AI.update_enemy(run, enemy, dt)
	local spec = archetypes[enemy.kind] or archetypes.stalker
	local state, visible = AI.describe(enemy, {
		world = run.world,
		player = run.player,
		alarm_time = run.alarm_time,
	})
	enemy.state = state
	enemy.cooldown = math.max(0, (enemy.cooldown or 0) - dt)
	enemy.alert_time = math.max(0, (enemy.alert_time or 0) - dt)
	enemy.search_time = math.max(0, (enemy.search_time or 0) - dt)
	enemy.retreat_time = math.max(0, (enemy.retreat_time or 0) - dt)

	local player_distance = util.distance(enemy.x, enemy.y, run.player.x, run.player.y)
	if visible then
		enemy.last_seen = {
			x = select(1, World.world_to_cell(run.player.x, run.player.y)),
			y = select(2, World.world_to_cell(run.player.x, run.player.y)),
		}
		enemy.search_time = 2.4
	end

	if player_distance <= 0.48 and enemy.cooldown <= 0 then
		enemy.cooldown = spec.attack_cooldown
		run:damage_player(spec.damage, enemy.kind .. " struck from the dark.")
		if enemy.kind == "leech" then
			run.player.light_charge = math.max(0, run.player.light_charge - 20)
			run.blackout_time = math.max(run.blackout_time, 1.5)
			enemy.retreat_time = 1.2
		end
		return
	end

	local player_cell_x, player_cell_y = World.world_to_cell(run.player.x, run.player.y)
	if state == "chase" then
		move_along_cells(run, enemy, spec.speed, dt, { x = player_cell_x, y = player_cell_y })
	elseif state == "search" and enemy.last_seen then
		move_along_cells(run, enemy, spec.speed * 0.8, dt, enemy.last_seen)
	elseif state == "retreat" and enemy.home then
		move_along_cells(run, enemy, spec.speed * 1.05, dt, enemy.home)
	elseif enemy.patrol then
		local target_cell = enemy.patrol_forward ~= false and enemy.patrol or enemy.home
		move_along_cells(run, enemy, spec.speed * 0.6, dt, target_cell)
		local cell_x, cell_y = World.world_to_cell(enemy.x, enemy.y)
		if target_cell and cell_x == target_cell.x and cell_y == target_cell.y then
			enemy.patrol_forward = enemy.patrol_forward == false
		end
	end

	if enemy.kind == "stalker" and state == "idle" then
		local facing = Geometry.facing_cardinal(enemy.facing or 0)
		enemy.facing = facing.angle
	end
end

return AI
