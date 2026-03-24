local util = require("src.core.util")
local World = require("src.world.world")

local AI = {}

local archetypes = {
	stalker = {
		speed = 1.35,
		damage = 1,
		range = 7.0,
		attack_cooldown = 0.85,
	},
	rusher = {
		speed = 1.55,
		damage = 2,
		range = 8.0,
		attack_cooldown = 1.0,
	},
	leech = {
		speed = 1.45,
		damage = 1,
		range = 6.0,
		attack_cooldown = 1.0,
	},
	sentry = {
		speed = 0.75,
		damage = 1,
		range = 7.5,
		attack_cooldown = 1.2,
	},
	umbra = {
		speed = 1.25,
		damage = 2,
		range = 10.0,
		attack_cooldown = 1.1,
	},
}

local function angle_delta(a, b)
	return math.abs(((a - b + math.pi) % (math.pi * 2)) - math.pi)
end

local function player_visible(enemy, context, spec)
	local distance = util.distance(enemy.x, enemy.y, context.player.x, context.player.y)
	if distance > spec.range then
		return false, distance
	end
	return World.has_line_of_sight(context.world, enemy.x, enemy.y, context.player.x, context.player.y), distance
end

local function sentry_can_see(enemy, context, spec)
	local visible, distance = player_visible(enemy, context, spec)
	if not visible then
		return false, distance
	end
	local angle_to_player = math.atan(context.player.y - enemy.y, context.player.x - enemy.x)
	return angle_delta(angle_to_player, enemy.facing or 0) < math.rad(34), distance
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
		return false
	end
	local next_cell = path[2]
	local target_x, target_y = World.cell_to_world(next_cell)
	move_toward(enemy, target_x, target_y, speed, dt)
	return true
end

function AI.describe(enemy, context)
	local spec = archetypes[enemy.kind] or archetypes.stalker
	local visible, distance
	if enemy.kind == "sentry" then
		visible, distance = sentry_can_see(enemy, context, spec)
	else
		visible, distance = player_visible(enemy, context, spec)
	end

	if enemy.kind == "leech" and enemy.retreat_time and enemy.retreat_time > 0 then
		return "retreat", visible, distance
	end
	if enemy.kind == "umbra" and not context.boss_active then
		return "idle", false, distance
	end
	if enemy.kind == "sentry" and visible then
		return "alarm", true, distance
	end
	if visible or (enemy.alert_time and enemy.alert_time > 0) or context.alarm_time > 0 then
		return "chase", visible, distance
	end
	if enemy.search_time and enemy.search_time > 0 then
		return "search", false, distance
	end
	return "idle", false, distance
end

function AI.update_enemy(run, enemy, dt)
	local spec = archetypes[enemy.kind] or archetypes.stalker
	local state, visible, player_distance = AI.describe(enemy, {
		world = run.world,
		player = run.player,
		alarm_time = run.alarm_time,
		boss_active = run.boss.active,
	})
	enemy.state = state
	enemy.cooldown = math.max(0, (enemy.cooldown or 0) - dt)
	enemy.alert_time = math.max(0, (enemy.alert_time or 0) - dt)
	enemy.search_time = math.max(0, (enemy.search_time or 0) - dt)
	enemy.retreat_time = math.max(0, (enemy.retreat_time or 0) - dt)

	local player_cell_x, player_cell_y = World.world_to_cell(run.player.x, run.player.y)
	if visible then
		enemy.last_seen = { x = player_cell_x, y = player_cell_y }
		enemy.search_time = math.max(enemy.search_time or 0, 2.2)
	end

	if enemy.kind == "sentry" and state == "alarm" then
		if enemy.cooldown <= 0 then
			enemy.cooldown = spec.attack_cooldown
			run:alarm_enemies(3.0)
			run:push_message("[shriek] a sentry has your scent.")
		end
		return
	end

	if player_distance and player_distance <= 0.48 and enemy.cooldown <= 0 then
		enemy.cooldown = spec.attack_cooldown
		run:damage_player(spec.damage, enemy.kind .. " struck from the dark.")
		if enemy.kind == "leech" then
			run.player.light_charge = math.max(0, run.player.light_charge - 26)
			run.blackout_time = math.max(run.blackout_time, 2.0)
			enemy.retreat_time = 1.4
		end
		return
	end

	if enemy.kind == "rusher" and visible then
		local ex, ey = World.world_to_cell(enemy.x, enemy.y)
		if ex == player_cell_x or ey == player_cell_y then
			move_along_cells(run, enemy, spec.speed * 2.1, dt, { x = player_cell_x, y = player_cell_y })
			return
		end
	end

	if enemy.kind == "umbra" then
		if player_distance > 3.2 then
			move_along_cells(run, enemy, spec.speed, dt, { x = player_cell_x, y = player_cell_y })
		elseif player_distance < 1.25 and enemy.home then
			move_along_cells(run, enemy, spec.speed * 0.9, dt, enemy.home)
		end
		return
	end

	if state == "chase" then
		move_along_cells(run, enemy, spec.speed, dt, { x = player_cell_x, y = player_cell_y })
	elseif state == "search" and enemy.last_seen then
		move_along_cells(run, enemy, spec.speed * 0.82, dt, enemy.last_seen)
	elseif state == "retreat" and enemy.home then
		move_along_cells(run, enemy, spec.speed * 1.05, dt, enemy.home)
	elseif enemy.patrol then
		local target_cell = enemy.patrol_forward ~= false and enemy.patrol or enemy.home
		move_along_cells(run, enemy, spec.speed * 0.6, dt, target_cell)
		local cell_x, cell_y = World.world_to_cell(enemy.x, enemy.y)
		if target_cell and cell_x == target_cell.x and cell_y == target_cell.y then
			enemy.patrol_forward = enemy.patrol_forward == false
		end
		if enemy.kind == "sentry" then
			enemy.facing = (enemy.facing or 0) + dt * 0.8
		end
	end
end

return AI
