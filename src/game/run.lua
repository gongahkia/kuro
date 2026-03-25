local util = require("src.core.util")
local RNG = require("src.core.rng")
local Events = require("src.core.events")
local Difficulty = require("src.data.difficulty")
local LoreData = require("src.data.lore")
local Geometry = require("src.world.geometry")
local World = require("src.world.world")
local Generator = require("src.world.generator")
local AI = require("src.game.ai")
local FX = require("src.render.fx")
local Codex = require("src.game.codex")
local Encounters = require("src.game.encounters")
local Audio = require("src.audio.audio")
local AudioManifest = require("src.data.audio_manifest")
local Relics = require("src.game.relics")
local Stealth = require("src.game.stealth")
local Sanity = require("src.game.sanity")
local Consumables = require("src.data.consumables")
local Challenges = require("src.game.challenges")
local Sprint = require("src.game.sprint")
local Momentum = require("src.game.momentum")

local Renderer

local Run = {}
Run.__index = Run

local lore_fragments = LoreData.fragments
local enemy_pressure = {
	stalker = { radius = 5.5, drain = 1.6 },
	rusher = { radius = 4.0, drain = 1.15 },
	leech = { radius = 4.6, drain = 1.45 },
	sentry = { radius = 5.0, drain = 0.9 },
	umbra = { radius = 8.5, drain = 2.6 },
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

function Run.new(difficulty, seed, mutators, settings, options)
	options = options or {}
	local base_profile = Difficulty.build(difficulty, 1, mutators)
	local mode = options.mode or "classic"
	local starting_health = base_profile.player_health - ((mutators and mutators.blacklight) and 2 or 0)
	if mutators and mutators.ironman then
		starting_health = 1
	end
	starting_health = math.max(1, starting_health)
	local self = setmetatable({
		difficulty = difficulty,
		difficulty_label = base_profile.label,
		seed = seed,
		mutators = util.deepcopy(mutators or {}),
		mode = mode,
		daily_label = options.daily_label,
		sprint_ruleset = options.sprint_ruleset,
		sprint_seed_pack_id = options.sprint_seed_pack_id,
		sprint_seed_id = options.sprint_seed_id,
		pack_version = options.pack_version or Sprint.get_pack_version(options.sprint_seed_pack_id),
		practice_target = options.practice_target,
		start_floor = options.start_floor or 1,
		official_record_eligible = options.official_record_eligible == true,
		loadout = options.loadout or "default",
		flame_color = options.flame_color or "amber",
		replay_mode = options.replay_mode == true,
		settings = settings or {},
		category = options.category or "any",
		category_key = options.category_key,
		events = Events.new(),
		total_floors = 3,
		floor = 1,
		clock = 0,
		timer_started = not (mode == "sprint" and options.sprint_ruleset == "official"),
		timer_armed = mode == "sprint" and options.sprint_ruleset == "official",
		timer_start_reason = mode == "sprint" and options.sprint_ruleset == "official" and "armed" or "immediate",
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
			consumables_used = 0,
			wards_triggered = 0,
			secrets_revealed = 0,
			pillars_destroyed = 0,
			burn_dashes = 0,
			flare_boosts = 0,
			propulsions = 0,
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
			weakened = 0,
			route = nil,
		},
		completed = false,
		momentum = Momentum.new(),
		player = {
			x = 0,
			y = 0,
			angle = 0,
			height = 0.55,
			radius = 0.18,
			move_speed = 2.6,
			strafe_speed = 2.35,
			turn_speed = 2.2,
			max_health = starting_health,
			health = starting_health,
			max_light_charge = 100 + (mutators and mutators.embers and 10 or 0),
			light_charge = 100 + (mutators and mutators.embers and 10 or 0),
			collected_torches = 0,
			inventory_torches = 0,
			torch_goal = base_profile.torch_goal,
			fire_cooldown = 0,
			burst_charge = 0,
			flares = base_profile.flare_count,
			consumables = { nil, nil, nil },
			ward_charges = 0,
			damage_taken_mult = (mutators and mutators.ironman) and 2 or 1,
			blacklight = mutators and mutators.blacklight == true or false,
			speed_boost_time = 0,
			speed_boost_mult = 1.0,
			invulnerability_time = 0,
			second_chance_used = false,
			dash_time = 0,
			dash_cooldown = 0,
			dash_vx = 0,
			dash_vy = 0,
			flare_line_window = 0,
			dash_feedback_time = 0,
			flare_feedback_time = 0,
		},
			time_attack_elapsed = 0,
			time_attack_level = 0,
			time_attack_enemy_mult = 1.0,
			time_attack_spawn_timer = Challenges.time_attack_spawn_interval(0),
			replay_save_requested = false,
			restart_requested = false,
			restart_hold_time = 0,
			restart_reason = nil,
			splits = {},
			split_index = {},
			last_split_delta = nil,
			pb_total_time = options.pb_total_time,
			pb_pack_version = options.pb_pack_version or "",
			pack_version_mismatch = options.pack_version_mismatch == true,
			mixed_split_versions = options.mixed_split_versions == true,
			pb_splits = util.deepcopy(options.pb_splits or {}),
			best_possible_time = options.best_possible_time,
			ghost_compare = {
				frames = util.deepcopy((options.ghost_compare and options.ghost_compare.frames) or {}),
				marker = nil,
				breadcrumbs = {},
			},
			medal_targets = util.deepcopy(options.medal_targets or {}),
			finish_splits_recorded = false,
			practice_goal = nil,
			practice_target_label = nil,
			route_events = {
				minimum_torch_pickups = 0,
				dark_lane_entries = 0,
				flare_line_boosts = 0,
				burn_lane_dashes = 0,
				pillar_route_breaks = 0,
			},
			route_cells_seen = {},
		}, Run)

	self.fx = FX.new(self.settings)
	self.codex = Codex.new()
	self.audio = Audio.new(self.settings)
	self.audio:load_manifest(AudioManifest)
	self.relics = Relics.new()
	self.stealth = Stealth.new()
	self.sanity = Sanity.new(100)
	self.is_moving = false
	self.pending_riddle = nil
	self.pending_sacrifice = nil
	if mode == "daily" then
		self.mode_label = "Daily Challenge"
	elseif mode == "time_attack" then
		self.mode_label = "Time Attack"
	elseif mode == "sprint" then
		self.mode_label = self.sprint_ruleset == "practice" and "Sprint Practice" or "Sprint Official"
	else
		self.mode_label = "Classic"
	end
	if self.mode == "sprint" and self.sprint_ruleset == "official" and not self.category_key then
		self.category_key = Sprint.category_key(self.difficulty, self.sprint_seed_pack_id, self.sprint_seed_id, self.category)
	end
	self.events:on("player_damaged", function()
		self.fx:trigger_shake(0.4, 0.2)
		self.audio:play("player_hit")
	end)
	self.events:on("burst_released", function()
		self.fx:trigger_shake(0.6, 0.3)
		self.audio:play("burst")
	end)
	self.events:on("enemy_killed", function(e)
		self.fx:trigger_death_anim(0, 0, e.enemy.kind)
		self.codex:record_enemy(e.enemy.kind)
		self.audio:play("enemy_death", { x = e.enemy.x, y = e.enemy.y })
	end)
	self.events:on("player_moved", function(e) self.is_moving = e.moving end)
	self.events:on("floor_loaded", function(e)
		local ambient = e.floor == 3 and "ambient_boss" or ("ambient_floor" .. math.min(e.floor, 2))
		self.audio:play_ambient(ambient)
	end)
	self.events:on("boss_phase_changed", function(e)
		self.audio:play_music("boss_phase" .. math.min(e.phase, 3))
	end)
	self.events:on("pickup_collected", function(e)
		if e.pickup.kind == "torch" then self.audio:play("pickup_torch") end
	end)
	if self.loadout == "scout" then
		self.player.flares = self.player.flares + 2
	end
	self:load_floor(self.start_floor)
	if self.mode == "sprint" and self.sprint_ruleset == "practice" and self.practice_target then
		self:apply_practice_target(self.practice_target)
	elseif self.mode == "sprint" and self.sprint_ruleset == "practice" and self.start_floor > 1 then
		self:apply_practice_target(string.format("floor:%d", self.start_floor))
	end
	return self
end

function Run:summary()
	local medal = nil
	if self.mode == "sprint" and self.sprint_ruleset == "official" then
		medal = Sprint.evaluate_medal(self.sprint_seed_pack_id, self.sprint_seed_id, self.difficulty, self.clock)
	end
	local gold_splits = {}
	for _, split in ipairs(self.splits) do
		if split.gold then
			gold_splits[#gold_splits + 1] = split.id
		end
	end
	return {
		seed = self.seed,
		difficulty = self.difficulty_label,
		difficulty_id = self.difficulty,
		floor = self.floor,
		mode = self.mode,
		mode_label = self.mode_label,
		daily_label = self.daily_label,
		sprint_ruleset = self.sprint_ruleset,
		sprint_seed_pack_id = self.sprint_seed_pack_id,
		sprint_seed_id = self.sprint_seed_id,
		pack_version = self.pack_version,
		practice_target = self.practice_target,
		practice_target_label = self.practice_target_label,
		official_record_eligible = self.official_record_eligible,
		category_key = self.category_key,
		loadout = self.loadout,
		flame_color = self.flame_color,
		duration = self.clock,
		sanity_left = self.sanity.sanity,
		stats = util.deepcopy(self.stats),
		splits = util.deepcopy(self.splits),
		medal = medal,
		gold_splits = gold_splits,
		best_possible_time = self.best_possible_time,
		timer_start_reason = self.timer_start_reason,
		projected_saves = Sprint.compute_projected_saves(self.pb_splits, self.splits, 3),
		pb_pack_version = self.pb_pack_version,
		pack_version_mismatch = self.pack_version_mismatch == true,
		mixed_split_versions = self.mixed_split_versions == true,
		tech_usage = {
			burn_dashes = self.stats.burn_dashes or 0,
			flare_boosts = self.stats.flare_boosts or 0,
		},
		route_events = util.deepcopy(self.route_events),
	}
end

function Run:push_message(message)
	self.messages[#self.messages + 1] = message
	if #self.messages > 8 then
		table.remove(self.messages, 1)
	end
end

function Run:begin_timer(reason)
	if self.timer_started or not self.timer_armed then
		return false
	end
	self.timer_started = true
	self.timer_start_reason = reason or "input"
	self:push_message(string.format("Sprint timer live on %s.", self.timer_start_reason))
	return true
end

function Run:apply_practice_snapshot(snapshot, floor)
	if not snapshot then
		return
	end
	self.player.max_light_charge = math.min(180, self.player.max_light_charge + (snapshot.light_bonus or 0))
	self.player.light_charge = self.player.max_light_charge
	self.player.health = math.max(1, math.floor(self.player.max_health * (snapshot.health_ratio or 1.0)))
	self.player.flares = self.player.flares + (snapshot.flare_bonus or 0)
	self.player.ward_charges = snapshot.wards or 0
	self.player.consumables = { nil, nil, nil }
	for index, kind in ipairs(snapshot.consumables or {}) do
		self.player.consumables[index] = kind
	end
	self.stats.floors_cleared = math.max(self.stats.floors_cleared, math.max(0, floor - 1))
	self:push_message(string.format("Practice snapshot loaded for floor %d.", floor))
end

function Run:apply_practice_target(target_id)
	local target = Sprint.get_practice_target(self.sprint_seed_pack_id, self.sprint_seed_id, target_id, self.difficulty)
	if not target then
		return
	end
	self.practice_target = target.id
	self.practice_target_label = target.label
	self.start_floor = target.floor or self.start_floor
	self:apply_practice_snapshot(target.snapshot, target.floor or self.floor)
	if target.kind == "drill" then
		local route = self.world.routeNodes and self.world.routeNodes[target.route_id] or nil
		if route and route.start_x and route.start_y then
			local start_x, start_y = route.start_x, route.start_y
			if self.world.spawn and route.start and route.finish and route.start.x == self.world.spawn.cell.x and route.start.y == self.world.spawn.cell.y then
				local path = World.find_path(self.world, route.start, route.finish, true)
				if path and path[2] then
					start_x, start_y = World.cell_to_world(path[2])
				end
			end
			self.player.x = start_x
			self.player.y = start_y
			if route.finish_x and route.finish_y then
				self.player.angle = math.atan(route.finish_y - self.player.y, route.finish_x - self.player.x)
			end
		end
		self.practice_goal = {
			target_id = target.id,
			label = target.label,
			kind = target.kind,
			floor = target.floor,
			route_id = target.route_id,
			goal = util.deepcopy(target.goal or {}),
			start_stats = {
				burn_dashes = self.stats.burn_dashes or 0,
				flare_boosts = self.stats.flare_boosts or 0,
				pillars_destroyed = self.stats.pillars_destroyed or 0,
				anchors_lit = self.stats.anchors_lit or 0,
			},
		}
		self:push_message(string.format("%s active.", target.label))
	else
		self.practice_goal = {
			target_id = target.id,
			label = target.label,
			kind = target.kind,
			floor = target.floor,
			goal = { type = "floor_clear", floor = target.floor },
		}
	end
end

function Run:mark_route_entry(tag, cell_x, cell_y)
	if not tag then
		return false
	end
	local key = string.format("%s:%d:%d", tag, cell_x, cell_y)
	if self.route_cells_seen[key] then
		return false
	end
	self.route_cells_seen[key] = true
	return true
end

function Run:find_route_node(kind, cell_x, cell_y, fields)
	for _, node in pairs(self.world.routeNodes or {}) do
		if not kind or node.kind == kind then
			for _, field in ipairs(fields or { "path" }) do
				for _, cell in ipairs(node[field] or {}) do
					if cell.x == cell_x and cell.y == cell_y then
						return node
					end
				end
			end
			if node.start and node.start.x == cell_x and node.start.y == cell_y then
				return node
			end
			if node.finish and node.finish.x == cell_x and node.finish.y == cell_y then
				return node
			end
		end
	end
	return nil
end

function Run:get_boss_route_pillar(priority)
	for _, pillar in ipairs(self.world.pillars or {}) do
		if pillar.route_priority == priority then
			return pillar
		end
	end
	return nil
end

function Run:get_boss_route_anchor(priority)
	for _, anchor in ipairs(self.world.anchors or {}) do
		if anchor.route_priority == priority then
			return anchor
		end
	end
	return nil
end

function Run:get_boss_route_target()
	local route = self.boss and self.boss.route or nil
	if not route or self.floor ~= self.total_floors then
		return nil
	end
	local pillar = self:get_boss_route_pillar(route.next_pillar_priority)
	if pillar and not pillar.destroyed then
		return {
			type = "pillar",
			label = route.next_pillar_priority == 1 and "Primary route pillar" or "Secondary route pillar",
			cell = pillar.cell,
			x = pillar.x,
			y = pillar.y,
		}
	end
	local anchor = self:get_boss_route_anchor(route.next_anchor_priority)
	if anchor and not anchor.lit then
		return {
			type = "anchor",
			label = string.format("Route anchor %d", route.next_anchor_priority),
			cell = anchor.cell,
			x = anchor.x,
			y = anchor.y,
			bonus_active = route.bonus_active == true,
		}
	end
	return nil
end

function Run:get_route_indicator()
	local target = self:get_boss_route_target()
	if not target then
		return nil
	end
	local dx = target.x - self.player.x
	local dy = target.y - self.player.y
	local distance = math.sqrt(dx * dx + dy * dy)
	local angle_to = math.atan(dy, dx)
	local delta = ((angle_to - self.player.angle + math.pi) % (math.pi * 2)) - math.pi
	return {
		label = target.label,
		type = target.type,
		distance = distance,
		angle_delta = delta,
		bonus_active = target.bonus_active == true,
	}
end

function Run:update_route_progress()
	local cell_x, cell_y = World.world_to_cell(self.player.x, self.player.y)
	local tags = World.get_cell_tags(self.world, cell_x, cell_y) or {}
	if tags.dark_lane then
		if self:mark_route_entry("dark_lane", cell_x, cell_y) then
			self.route_events.dark_lane_entries = self.route_events.dark_lane_entries + 1
		end
	end
	if tags.flare_checkpoint and self.player.flare_line_window > 0 then
		local node = self:find_route_node("flare_line", cell_x, cell_y, { "checkpoints" })
		if node and self:mark_route_entry("flare_checkpoint", cell_x, cell_y) then
			self.player.speed_boost_time = math.max(self.player.speed_boost_time, 1.2 + (node.boost_extension or 0.32))
			self.player.speed_boost_mult = math.max(self.player.speed_boost_mult, node.speed_mult or 1.46)
			self.player.flare_feedback_time = 0.8
			self.route_events.flare_line_boosts = self.route_events.flare_line_boosts + 1
			self:push_message("[route] the flare line catches and carries you onward.")
		end
	end
	if tags.burn_gate and self.player.dash_time > 0 then
		local node = self:find_route_node("burn_lane", cell_x, cell_y, { "gate_cells" })
		if node and self:mark_route_entry("burn_gate", cell_x, cell_y) then
			self.player.dash_time = self.player.dash_time + (node.dash_extension or 0.08)
			self.player.light_charge = math.min(self.player.max_light_charge, self.player.light_charge + (node.light_refund or 0))
			self.player.dash_feedback_time = 0.8
			self.route_events.burn_lane_dashes = self.route_events.burn_lane_dashes + 1
			self:push_message("[route] the burn gate extends the dash.")
		end
	end
end

function Run:get_split_stack()
	if self.mode ~= "sprint" then
		return nil
	end
	local plan = Sprint.get_split_plan()
	local last_split = self.splits[#self.splits]
	local next_split = nil
	for _, info in ipairs(plan) do
		if not self.split_index[info.id] then
			next_split = info
			break
		end
	end
	local segment_start = last_split and last_split.time or 0
	local projected_finish, projected_delta = Sprint.projected_finish(self.pb_splits, self.splits, self.clock)
	local rows = Sprint.get_split_rows(self.pb_splits, self.splits)
	local last_row = rows[#rows]
	return {
		last = last_split,
		next = next_split,
		current_segment_time = math.max(0, self.clock - segment_start),
		projected_finish = projected_finish,
		projected_delta = projected_delta,
		best_possible_time = self.best_possible_time,
		last_segment_time = last_row and last_row.segment_time or nil,
		last_segment_best = last_row and last_row.best_segment_time or nil,
	}
end

function Run:get_ghost_cue()
	local marker = self.ghost_compare and self.ghost_compare.marker or nil
	if not marker or marker.floor ~= self.floor then
		return nil
	end
	local dx = marker.x - self.player.x
	local dy = marker.y - self.player.y
	local distance = math.sqrt(dx * dx + dy * dy)
	local angle_to = math.atan(dy, dx)
	local delta = ((angle_to - self.player.angle + math.pi) % (math.pi * 2)) - math.pi
	return {
		distance = distance,
		angle_delta = delta,
	}
end

function Run:record_split(id, label, floor)
	if self.split_index[id] then
		return self.split_index[id]
	end
	local split = {
		id = id,
		label = label,
		floor = floor or self.floor,
		time = self.clock,
	}
	for _, other in ipairs(self.pb_splits or {}) do
		if other.id == id and other.time then
			split.delta = self.clock - other.time
			split.gold = self.clock < other.time
			self.last_split_delta = split.delta
			break
		end
	end
	self.splits[#self.splits + 1] = split
	self.split_index[id] = split
	return split
end

function Run:get_medal_pace()
	if self.mode ~= "sprint" or self.sprint_ruleset ~= "official" then
		return nil
	end
	local medal, target, delta = Sprint.get_pace_target(self.sprint_seed_pack_id, self.sprint_seed_id, self.difficulty, self.clock)
	if not medal or not target then
		return nil
	end
	return {
		medal = medal,
		target = target,
		delta = delta,
	}
end

function Run:update_ghost_compare()
	local compare = self.ghost_compare
	if not compare or not compare.frames or #compare.frames == 0 then
		return
	end
	compare.breadcrumbs = {}
	compare.marker = nil
	for _, frame in ipairs(compare.frames) do
		if frame.timestamp <= self.clock then
			if frame.floor == self.floor then
				compare.breadcrumbs[#compare.breadcrumbs + 1] = frame
				compare.marker = frame
			end
		else
			break
		end
	end
end

function Run:can_reach_anchor(anchor, current_cell, target_cell)
	if same_cell(anchor.cell, current_cell) or same_cell(anchor.cell, target_cell) then
		return true
	end
	if self.floor == self.total_floors and (self.boss.weakened or 0) > 0 then
		local bonus = 0
		local route = self.boss and self.boss.route or nil
		if route and route.bonus_active and anchor.route_priority == route.next_anchor_priority then
			bonus = route.anchor_range_bonus or 0
		end
		return util.distance(self.player.x, self.player.y, anchor.x, anchor.y) <= (1.2 + (self.boss.weakened or 0) * 0.18 + bonus)
	end
	return false
end

function Run:load_floor(floor)
	local config = Difficulty.build(self.difficulty, floor, self.mutators)
	self.floor = floor
	self.floor_config = config
	self.world = Generator.generate(self.difficulty, self.seed, floor, self.mutators, {
		mode = self.mode,
		sprint_ruleset = self.sprint_ruleset,
		sprint_seed_pack_id = self.sprint_seed_pack_id,
		sprint_seed_id = self.sprint_seed_id,
	})
	self.player.x = self.world.spawn.x
	self.player.y = self.world.spawn.y
	self.player.angle = self.world.spawn.angle or 0
	self.player.collected_torches = 0
	self.player.inventory_torches = 0
	self.player.torch_goal = floor < self.total_floors and config.torch_goal or #self.world.anchors
	self.player.flares = config.flare_count + ((floor == 1 and self.loadout == "scout") and 2 or 0)
	self.player.light_charge = self.player.max_light_charge
	self.player.burst_charge = 0
	self.player.speed_boost_time = 0
	self.player.speed_boost_mult = 1.0
	self.player.invulnerability_time = 0
	self.player.second_chance_used = false
	self.player.dash_time = 0
	self.player.dash_cooldown = 0
	self.player.dash_vx = 0
	self.player.dash_vy = 0
	self.player.flare_line_window = 0
	self.player.dash_feedback_time = 0
	self.player.flare_feedback_time = 0
	self.blackout_time = 0
	self.alarm_time = 0
	self.guidance_time = 0
	self.guidance_cells = {}
	self.revealed = {}
	self.hazards = {}
	self.flares = {}
	self.damage_flash = 0
	self.completed = false
	self.finish_splits_recorded = false
	self.restart_requested = false
	self.restart_reason = nil
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
		weakened = self.boss and self.boss.weakened or 0,
		route = nil,
	}
	local pillar_route = self.world.routeNodes and self.world.routeNodes.pillar_route_3 or nil
	if floor == self.total_floors and pillar_route then
		self.boss.route = {
			next_pillar_priority = 1,
			next_anchor_priority = 1,
			bonus_active = false,
			hazard_mult = pillar_route.hazard_mult or 0.76,
			anchor_range_bonus = pillar_route.anchor_range_bonus or 0.7,
			anchor_restore = pillar_route.anchor_restore or 12,
		}
	end
	self:refresh_secret_clues()

	if floor == self.total_floors then
		self:push_message(string.format("Floor %d: the chamber breathes. Carry fire to %d anchors.", floor, #self.world.anchors))
	else
		self:push_message(string.format("Floor %d: collect %d torches and breach the exit.", floor, config.torch_goal))
	end
	if self.mode == "daily" and self.daily_label then
		self:push_message("Daily profile " .. self.daily_label .. ".")
	elseif self.mode == "time_attack" then
		self:push_message("Time attack active: pressure escalates every 30 seconds.")
	elseif self.mode == "sprint" then
		if self.sprint_ruleset == "official" then
			self:push_message("Sprint official: medals, PBs, and ghosts are active.")
			if self.timer_armed and not self.timer_started then
				self:push_message("Timer armed. First movement or action starts the run.")
			end
		else
			self:push_message(string.format("Sprint practice target: %s.", self.practice_target_label or self.practice_target or ("floor:" .. tostring(self.start_floor))))
		end
	end
	self:record_split(string.format("floor_%d_start", floor), string.format("Floor %d Start", floor), floor)
	self:reveal_nearby()
	self.events:emit("floor_loaded", { floor = floor })
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
	if self.player.invulnerability_time > 0 then
		return
	end
	amount = math.max(0, amount or 0) * (self.player.damage_taken_mult or 1.0)
	if self.player.ward_charges > 0 and amount > 0 then
		self.player.ward_charges = self.player.ward_charges - 1
		self.player.invulnerability_time = 1.4
		self.stats.wards_triggered = self.stats.wards_triggered + 1
		self.sanity:restore(12)
		self:push_message("A ward cracks and shields you from the blow.")
		return
	end
	if self.player.health - amount <= 0 and self.relics:has_effect("second_chance") and not self.player.second_chance_used then
		self.player.second_chance_used = true
		self.player.health = 1
		self.player.invulnerability_time = 1.8
		self.sanity:restore(18)
		self:push_message("Undying Ember flares and denies the dark.")
		return
	end
	self.player.health = math.max(0, self.player.health - amount)
	self.damage_flash = 0.32
	self.stats.damage_taken = self.stats.damage_taken + amount
	if reason then
		self:push_message(reason)
	end
	self.events:emit("player_damaged", { amount = amount, reason = reason, health = self.player.health })
end

function Run:current_objective_cell()
	if self.practice_goal and self.practice_goal.kind == "drill" then
		local goal = self.practice_goal.goal or {}
		if goal.type == "collect_route_pickup" then
			for _, pickup in ipairs(self.world.pickups) do
				if pickup.active and pickup.route_role == goal.route_role then
					return { x = pickup.cell.x, y = pickup.cell.y }
				end
			end
		end
		local route = self.practice_goal.route_id and self.world.routeNodes and self.world.routeNodes[self.practice_goal.route_id] or nil
		if route and route.finish then
			return { x = route.finish.x, y = route.finish.y }
		end
	end

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

	local route_target = self:get_boss_route_target()
	if route_target and route_target.cell and (route_target.type == "pillar" or self.player.inventory_torches > 0) then
		return { x = route_target.cell.x, y = route_target.cell.y }
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

function Run:restore_sanity(amount, message)
	self.sanity:restore(amount)
	if message then
		self:push_message(message)
	end
end

function Run:apply_sanity_shock(amount, message)
	self.sanity:apply(amount)
	if message then
		self:push_message(message)
	end
end

function Run:add_consumable(kind)
	for index = 1, 3 do
		if not self.player.consumables[index] then
			self.player.consumables[index] = kind
			return true, index
		end
	end
	return false
end

function Run:spawn_pickup(kind, cell, extra)
	local x, y = cell_center(cell)
	local pickup = {
		kind = kind,
		cell = { x = cell.x, y = cell.y },
		x = x,
		y = y,
		active = true,
		radius = 0.24,
	}
	if extra then
		for key, value in pairs(extra) do
			pickup[key] = value
		end
	end
	self.world.pickups[#self.world.pickups + 1] = pickup
	return pickup
end

function Run:get_current_tags()
	local cell_x, cell_y = World.world_to_cell(self.player.x, self.player.y)
	return World.get_cell_tags(self.world, cell_x, cell_y) or {}
end

function Run:get_enemy_pressure()
	local total = 0
	for _, enemy in ipairs(self.world.enemies) do
		if enemy.alive ~= false then
			local spec = enemy_pressure[enemy.kind]
			if spec then
				local distance = util.distance(self.player.x, self.player.y, enemy.x, enemy.y)
				if distance <= spec.radius then
					total = total + spec.drain * (1 - (distance / spec.radius) * 0.65)
				end
			end
		end
	end
	return math.max(0, total)
end

function Run:refresh_secret_clues()
	if not self.world or not self.world.secret_walls then
		return
	end
	for _, secret in ipairs(self.world.secret_walls) do
		if secret.reveal_method == "lore_clue" and not secret.revealed then
			local required = secret.required_fragment
			local unlocked = required == nil or (self.codex and self.codex:is_fragment_found(required))
			if unlocked then
				secret.revealed = true
				self.stats.secrets_revealed = self.stats.secrets_revealed + 1
				local door = World.get_door_between(self.world, secret.cell_a.x, secret.cell_a.y, secret.cell_b.x, secret.cell_b.y)
				if door then
					door.secret = false
					door.target = 1
				end
				self:push_message("[clue] a remembered fragment exposes a hidden seam.")
			end
		end
	end
end

function Run:damage_pillar(pillar, amount)
	if not pillar or pillar.destroyed then
		return false
	end
	pillar.health = pillar.health - amount
	if pillar.health <= 0 then
		pillar.destroyed = true
		local weaken_amount = self.mode == "sprint" and 1.4 or 1
		local route = self.boss and self.boss.route or nil
		local expected_break = route and pillar.route_priority and pillar.route_priority == route.next_pillar_priority
		if pillar.route_role == "pillar_route" then
			weaken_amount = weaken_amount + (pillar.weaken_bonus or 0.5)
			self.route_events.pillar_route_breaks = self.route_events.pillar_route_breaks + 1
			if expected_break then
				route.bonus_active = true
				while self:get_boss_route_pillar(route.next_pillar_priority) and self:get_boss_route_pillar(route.next_pillar_priority).destroyed do
					route.next_pillar_priority = route.next_pillar_priority + 1
				end
				self:push_message("[route] the pillar order holds. The next anchor window opens.")
			elseif route then
				self:push_message("[route] the pillar breaks off line. Only the weaken bonus remains.")
			end
		end
		self.boss.weakened = (self.boss.weakened or 0) + weaken_amount
		self.stats.pillars_destroyed = self.stats.pillars_destroyed + 1
		self:push_message("[crash] a pillar collapses and Umbra's rhythm falters.")
		return true
	end
	return false
end

function Run:try_damage_pillars_in_cone(range, half_angle, damage)
	for _, pillar in ipairs(self.world.pillars or {}) do
		if not pillar.destroyed then
			local dx = pillar.x - self.player.x
			local dy = pillar.y - self.player.y
			local distance = math.sqrt(dx * dx + dy * dy)
			if distance <= range then
				local angle_to = math.atan(dy, dx)
				local diff = math.abs(((angle_to - self.player.angle + math.pi) % (math.pi * 2)) - math.pi)
				if diff <= half_angle then
					self:damage_pillar(pillar, damage)
				end
			end
		end
	end
end

function Run:drop_enemy_loot(enemy)
	local cell = { x = select(1, World.world_to_cell(enemy.x, enemy.y)), y = select(2, World.world_to_cell(enemy.x, enemy.y)) }
	local roll = self.rng:float()
	if enemy.kind == "leech" and roll < 0.24 then
		self:spawn_pickup("calming_tonic", cell)
	elseif enemy.kind == "sentry" and roll < 0.22 then
		self:spawn_pickup("ward_charge", cell)
	elseif enemy.kind == "rusher" and roll < 0.18 then
		self:spawn_pickup("speed_tonic", cell)
	elseif roll < 0.12 then
		self:spawn_pickup("ration", cell)
	end
end

function Run:reveal_nearby()
	local origin_x, origin_y = World.world_to_cell(self.player.x, self.player.y)
	local radius = math.max(4, math.floor(self.floor_config.view_distance * 0.42)) + self.relics:get_value("reveal_radius_add", 0)
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
		local noise = self.sanity:get_effects().guidance_noise
		for _, cell in ipairs(path) do
			local picked = cell
			if noise > 0 and self.rng:chance(noise) then
				local neighbors = World.neighbors(self.world, cell.x, cell.y, { allow_closed_doors = true })
				if #neighbors > 0 then
					local choice = neighbors[self.rng:int(1, #neighbors)]
					picked = { x = choice.x, y = choice.y }
				end
			end
			self.guidance_cells[cell_key(picked)] = true
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

function Run:query_nearest_wall(px, py, fx, fy)
	local cell_x, cell_y = World.world_to_cell(px, py)
	local best_dist = math.huge
	local best_wall = nil
	for y = cell_y - 1, cell_y + 1 do
		for x = cell_x - 1, cell_x + 1 do
			local sector = World.get_sector_by_cell(self.world, x, y)
			if sector then
				for _, wall in ipairs(sector.walls) do
					local blocking = wall.neighbor == nil or (wall.door_id and not World.is_door_open(self.world, wall.door_id))
					if blocking then
						local dist = Geometry.distance_to_segment(px, py, wall.a.x, wall.a.y, wall.b.x, wall.b.y)
						if dist < 0.23 and dist < best_dist then
							best_dist = dist
							best_wall = wall
						end
					end
				end
			end
		end
	end
	if not best_wall then return nil end
	local nx, ny = Geometry.wall_normal(best_wall)
	return { normal_x = nx, normal_y = ny, distance = best_dist }
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
	if self.keys.c then
		strafe = strafe + 1
	end
	if self.keys.a then
		turn = turn - 1
	end
	if self.keys.d then
		turn = turn + 1
	end

	local jitter = self.sanity:get_effects().control_jitter
	self.player.angle = util.wrap_angle(self.player.angle + turn * self.player.turn_speed * dt + (jitter > 0 and (math.random() - 0.5) * jitter * dt or 0))

	local stealth_mult = self.stealth:get_speed_multiplier(self.momentum:is_sliding())
	local dark_mult = (self.blackout_time > 0 and self.relics:get_value("dark_speed_mult", 1.0)) or 1.0
	local move_speed = self.player.move_speed * stealth_mult * dark_mult * self.player.speed_boost_mult
	local strafe_speed = self.player.strafe_speed * stealth_mult * dark_mult * self.player.speed_boost_mult
	local momentum_input = {
		move = move,
		strafe = strafe,
		turn = turn,
		crouch = self.keys.lctrl or false,
		move_speed = move_speed,
		strafe_speed = strafe_speed,
	}
	local wall_query = function(px, py, fx, fy)
		return self:query_nearest_wall(px, py, fx, fy)
	end
	local vx, vy = self.momentum:update(dt, momentum_input, self.player, wall_query)

	self:attempt_axis(self.player.x + vx * dt, self.player.y)
	self:attempt_axis(self.player.x, self.player.y + vy * dt)
	if self.player.dash_time > 0 then
		local dash_dt = math.min(dt, self.player.dash_time)
		local step_dt = dash_dt / 4
		for _ = 1, 4 do
			self:attempt_axis(self.player.x + self.player.dash_vx * step_dt, self.player.y)
			self:attempt_axis(self.player.x, self.player.y + self.player.dash_vy * step_dt)
		end
	end

	if self.keys.lshift then
		self.player.burst_charge = math.min(1.5, self.player.burst_charge + dt)
	end
	self.is_moving = self.momentum:get_speed() > 0.1 or self.player.dash_time > 0
	self:update_route_progress()
	self.events:emit("player_moved", { x = self.player.x, y = self.player.y, moving = self.is_moving })
end

function Run:update_practice_goal()
	if not self.practice_goal or self.completed then
		return
	end
	local goal = self.practice_goal.goal or {}
	local route = self.practice_goal.route_id and self.world.routeNodes and self.world.routeNodes[self.practice_goal.route_id] or nil
	if goal.type == "reach_route_end" and route and route.finish then
		local cell_x, cell_y = World.world_to_cell(self.player.x, self.player.y)
		if cell_x == route.finish.x and cell_y == route.finish.y then
			if goal.require == "burn_dash" and (self.stats.burn_dashes or 0) <= (self.practice_goal.start_stats.burn_dashes or 0) then
				return
			end
			if goal.require == "flare_boost" and (self.stats.flare_boosts or 0) <= (self.practice_goal.start_stats.flare_boosts or 0) then
				return
			end
			self.completed = true
			self:push_message("Drill complete. Route end reached.")
		end
	end
end

function Run:spawn_enemy(kind, origin_cell, modifier)
	local EnemyData = require("src.data.enemies")
	local archetype = EnemyData.archetypes[kind] or EnemyData.archetypes.stalker
	local base_health = archetype.health or (kind == "stalker" and 35 or 45)
	local mod = modifier and EnemyData.modifiers[modifier] or nil
	if mod and mod.health_mult then base_health = math.floor(base_health * mod.health_mult) end
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
							modifier = modifier,
							cell = { x = x, y = y },
							home = { x = x, y = y },
							patrol = { x = origin_x, y = origin_y },
							state = "search",
							health = base_health,
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

function Run:handle_enemy_death(enemy)
	enemy.alive = false
	self.stats.enemies_burned = self.stats.enemies_burned + 1
	self:drop_enemy_loot(enemy)
	self.events:emit("enemy_killed", { enemy = enemy })
	if enemy.modifier then
		local EnemyData = require("src.data.enemies")
		local mod = EnemyData.modifiers[enemy.modifier]
		if mod and mod.on_death == "split" then
			local prevent = self.relics and self.relics:has_effect("prevent_split")
			if not prevent then
				local cell = { x = select(1, World.world_to_cell(enemy.x, enemy.y)), y = select(2, World.world_to_cell(enemy.x, enemy.y)) }
				for _ = 1, (mod.split_count or 2) do
					self:spawn_enemy(mod.split_kind or "stalker", cell)
				end
				self:push_message("The " .. enemy.kind .. " splits apart.")
			end
		end
	end
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
	return Encounters.pick(self.rng, self.floor, self.director.threat_remaining > 0)
end

function Run:apply_encounter(node, kind)
	Encounters.apply(self, node, kind)
end

function Run:update_encounters()
	local cell_x, cell_y = World.world_to_cell(self.player.x, self.player.y)
	for _, node in ipairs(self.world.encounterNodes) do
		if not node.triggered and node.cell.x == cell_x and node.cell.y == cell_y then
			node.triggered = true
			self.stats.encounters_triggered = self.stats.encounters_triggered + 1
			local kind = node.kind == "lore" and "lore" or self:pick_encounter()
			self.events:emit("encounter_triggered", { node = node, kind = kind })
			self:apply_encounter(node, kind)
		end
	end

		if self.floor == self.total_floors and self.world.bossRoom and not self.boss.active then
			for _, cell in ipairs(self.world.bossRoom.cells) do
				if cell.x == cell_x and cell.y == cell_y then
					self.boss.active = true
					self:record_split("boss_start", "Boss Start", self.floor)
					self:push_message("[pulse] Umbra wakes and the room begins to breathe.")
					break
				end
			end
		end
end

function Run:collect_pickup(pickup)
	local consumed = true
	if pickup.kind == "torch" then
		self.player.collected_torches = self.player.collected_torches + 1
		self.player.inventory_torches = self.player.inventory_torches + 1
		local light_bonus = 8 * self.relics:get_value("torch_light_mult", 1.0)
		self.player.max_light_charge = math.min(180, self.player.max_light_charge + light_bonus)
		self.player.light_charge = math.min(self.player.max_light_charge, self.player.light_charge + 24)
		self.stats.torches_collected = self.stats.torches_collected + 1
		self.sanity:restore(8)
		self:push_message(string.format("Torch claimed %d / %d.", self.player.collected_torches, self.player.torch_goal))
	elseif pickup.kind == "shrine" then
		self.player.health = math.min(self.player.max_health, self.player.health + 2)
		self.player.light_charge = self.player.max_light_charge
		self.sanity:restore(34)
		self:push_message("The shrine steadies your breathing and flame.")
	elseif pickup.kind == "ration" then
		self.sanity:restore(18)
		self:push_message("You consume the ration. The shaking eases.")
	elseif pickup.kind == "note" then
		self.sanity:restore(10)
		self:push_message("[note] " .. (pickup.text or "The ink has faded."))
		if self.codex then
			local lore = LoreData.fragments
			self.director.lore_index = self.director.lore_index + 1
			local entry = lore[((self.director.lore_index - 1) % #lore) + 1]
			self.codex:discover_fragment(entry.id)
		end
		self:refresh_secret_clues()
	elseif pickup.kind == "relic" then
		local RelicData = require("src.data.relics")
		local pool = {}
		for _, r in ipairs(RelicData) do pool[#pool + 1] = r end
		if #pool > 0 then
			local relic = self.rng:choice(pool)
			if self.relics:add(relic) then
				self.relics:apply_stat_modifiers(self.player)
				self:push_message("[relic] " .. relic.label .. ": " .. relic.desc)
			else
				self:push_message("Your hands are full. The relic crumbles.")
			end
		end
	elseif Consumables.get(pickup.kind) then
		local added = self:add_consumable(pickup.kind)
		if added then
			self:push_message("Recovered " .. Consumables.get(pickup.kind).label .. ".")
		else
			consumed = false
			self:push_message("Your belt is full. Leave something or move on.")
		end
	end
	if consumed then
		if pickup.route_role == "minimum_torch" then
			self.route_events.minimum_torch_pickups = self.route_events.minimum_torch_pickups + 1
			if self.practice_goal and self.practice_goal.goal and self.practice_goal.goal.type == "collect_route_pickup" and self.practice_goal.goal.route_role == pickup.route_role then
				self.completed = true
			end
		end
		pickup.active = false
		self.events:emit("pickup_collected", { pickup = pickup })
	end
	return consumed
end

function Run:use_consumable(slot)
	local kind = self.player.consumables[slot]
	if not kind then
		self:push_message("That belt slot is empty.")
		return
	end

	local def = Consumables.get(kind)
	if not def then
		self.player.consumables[slot] = nil
		return
	end

	if kind == "calming_tonic" then
		self.sanity:restore(38)
		self:push_message("The tonic steadies your breathing.")
	elseif kind == "speed_tonic" then
		self.player.speed_boost_time = def.duration or 8.0
		self.player.speed_boost_mult = math.max(self.player.speed_boost_mult, def.speed_mult or 1.25)
		self:push_message("Your steps turn sharp and urgent.")
	elseif kind == "ward_charge" then
		self.player.ward_charges = self.player.ward_charges + 1
		self.sanity:restore(def.restore_sanity or 16)
		self:push_message("A ward settles around your flame.")
	end

	self.player.consumables[slot] = nil
	self.stats.consumables_used = self.stats.consumables_used + 1
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
	self.sanity:restore(8)
	local route = self.boss and self.boss.route or nil
	local expected_anchor = route and anchor.route_priority and anchor.route_priority == route.next_anchor_priority
	if route and expected_anchor then
		route.next_anchor_priority = route.next_anchor_priority + 1
		if route.bonus_active then
			self.sanity:restore(route.anchor_restore or 12)
			self.boss.pulse_timer = math.max(self.boss.pulse_timer or 0, 1.8)
			self.boss.wall_timer = math.max(self.boss.wall_timer or 0, 2.1)
			self.boss.summon_timer = math.max(self.boss.summon_timer or 0, 2.4)
			route.bonus_active = false
			self:push_message("[route] the authored line lands cleanly and the chamber slows.")
		else
			self:push_message("[route] you realign with the authored anchor order.")
		end
	elseif route and anchor.route_priority then
		self:push_message("[route] the anchor lights, but the fastest line slips.")
	end
	self:push_message(string.format("Anchor lit %d / %d.", self.stats.anchors_lit, #self.world.anchors))
	if self.stats.anchors_lit >= #self.world.anchors then
		self:record_split("final_anchor_lit", "Final Anchor Lit", self.floor)
		self.completed = true
		self:push_message("Umbra buckles under the light. You survive the abyss.")
	elseif self.practice_goal and self.practice_goal.goal and self.practice_goal.goal.type == "pillar_anchor" then
		local required_pillars = self.practice_goal.goal.required_pillars or 1
		local required_anchors = self.practice_goal.goal.required_anchors or 1
		if self.stats.pillars_destroyed >= required_pillars and self.stats.anchors_lit >= required_anchors then
			self.completed = true
			self:push_message("Drill complete. The route holds.")
		end
	end
end

function Run:interact()
	local cell_x, cell_y = World.world_to_cell(self.player.x, self.player.y)
	local current_cell = { x = cell_x, y = cell_y }
	local facing = Geometry.facing_cardinal(self.player.angle)
	local target_cell = { x = cell_x + facing.dx, y = cell_y + facing.dy }

	if self.pending_riddle then
		if facing.name == self.pending_riddle.answer then
			local reward = self.pending_riddle.reward
			if reward == "torch" then
				self.player.inventory_torches = self.player.inventory_torches + 1
				self.player.collected_torches = self.player.collected_torches + 1
				self:push_message("The riddle yields a torch.")
			elseif reward == "light" then
				self.player.light_charge = self.player.max_light_charge
				self:push_message("Light floods back into your flame.")
			elseif reward == "flare" then
				self.player.flares = self.player.flares + 1
				self:push_message("A flare materializes in your hand.")
			elseif reward == "tonic" then
				self:add_consumable("calming_tonic")
				self:push_message("The riddle yields a calming tonic.")
			end
			self.pending_riddle = nil
		else
			self:push_message("The riddle rejects your answer.")
		end
		return
	end

	if self.pending_sacrifice then
		self:damage_player(self.pending_sacrifice.cost, "You offer blood to the altar.")
		self.player.light_charge = self.player.max_light_charge
		self.sanity:restore(20)
		self:push_message("The altar drinks and your flame roars.")
		self.pending_sacrifice = nil
		return
	end

	local door = World.get_door_between(self.world, current_cell.x, current_cell.y, target_cell.x, target_cell.y)
	if door then
		door.target = door.target < 0.5 and 1 or 0
		self:push_message(door.target > 0 and "Door winding open." or "Door sealing shut.")
		self.audio:play("door_open")
		return
	end

	for _, pickup in ipairs(self.world.pickups) do
		if pickup.active and (same_cell(pickup.cell, current_cell) or same_cell(pickup.cell, target_cell)) then
			self:collect_pickup(pickup)
			return
		end
	end

	for _, anchor in ipairs(self.world.anchors) do
		if self:can_reach_anchor(anchor, current_cell, target_cell) then
			self:try_use_anchor(anchor)
			return
		end
	end

	if self.world.exit and (same_cell(self.world.exit.cell, current_cell) or same_cell(self.world.exit.cell, target_cell)) then
		if self.player.collected_torches >= self.player.torch_goal then
			self.stats.floors_cleared = self.stats.floors_cleared + 1
			self:record_split(string.format("floor_%d_clear", self.floor), string.format("Floor %d Clear", self.floor), self.floor)
			if self.practice_goal and self.practice_goal.goal and self.practice_goal.goal.type == "floor_clear" and self.practice_goal.goal.floor == self.floor then
				self.completed = true
				self:push_message("Practice floor complete.")
			elseif self.floor < self.total_floors then
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

function Run:try_burn_dash(charge)
	if charge < 0.55 or self.player.dash_cooldown > 0 then
		return false
	end
	local move = 0
	local strafe = 0
	if self.keys.w then
		move = move + 1
	end
	if self.keys.s then
		move = move - 1
	end
	if self.keys.q then
		strafe = strafe - 1
	end
	if self.keys.c then
		strafe = strafe + 1
	end
	local forward_x = math.cos(self.player.angle)
	local forward_y = math.sin(self.player.angle)
	local right_x = -math.sin(self.player.angle)
	local right_y = math.cos(self.player.angle)
	local dir_x, dir_y, length = util.normalize(forward_x * move + right_x * strafe, forward_y * move + right_y * strafe)
	if length <= 0 then
		return false
	end
	local dash_cost = 6 + charge * 8
	if self.player.light_charge < dash_cost then
		return false
	end
	self.player.light_charge = self.player.light_charge - dash_cost
	self.player.dash_time = 0.18 + charge * 0.08
	self.player.dash_cooldown = 0.55
	self.player.dash_vx = dir_x * (5.4 + charge * 2.8)
	self.player.dash_vy = dir_y * (5.4 + charge * 2.8)
	self.player.dash_feedback_time = 0.5
	self.stats.burn_dashes = self.stats.burn_dashes + 1
	self.momentum:notify_tech("burn_dash_bhop")
	self:push_message("[dash] the burst hurls you forward.")
	return true
end

function Run:release_burst()
	local charge = self.player.burst_charge
	if charge <= 0.2 then
		self.player.burst_charge = 0
		return
	end
	local cost = (14 + charge * 22) * self.relics:get_value("burst_cost_mult", 1.0)
	if self.player.light_charge < cost then
		self:push_message("Your flame is too weak for a burst.")
		self.player.burst_charge = 0
		return
	end
	self.player.light_charge = self.player.light_charge - cost
	self.player.burst_charge = 0
	self:try_burn_dash(charge)
	self.stealth:add_burst_noise()
	self:try_damage_pillars_in_cone(3.4 + charge * 2.2, math.rad(50), 22 + charge * 18)
	self.events:emit("burst_released", { charge = charge })
	self:push_message("[flare-burst] the chamber recoils from the light.")
	if self.category ~= "pacifist" then
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
						self:handle_enemy_death(enemy)
					end
				end
			end
		end
	end
	-- reveal secret doors within burst range
	if self.world.secret_walls then
		local player_cx, player_cy = World.world_to_cell(self.player.x, self.player.y)
		for _, secret in ipairs(self.world.secret_walls) do
			if secret.reveal_method == "burst" and not secret.revealed then
				local dist = math.abs(secret.cell_b.x - player_cx) + math.abs(secret.cell_b.y - player_cy)
				if dist <= math.ceil(2.6 + charge * 2.4) then
					secret.revealed = true
					local door = World.get_door_between(self.world, secret.cell_a.x, secret.cell_a.y, secret.cell_b.x, secret.cell_b.y)
					if door then
						door.secret = false
						door.target = 1
					end
					self.stats.secrets_revealed = self.stats.secrets_revealed + 1
					self:push_message("[crack] a hidden passage shudders open.")
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
		boost_window = 1.1,
		boosted = false,
	}
	self.player.flares = self.player.flares - 1
	self.stats.flares_used = self.stats.flares_used + 1
	self:push_message("[clink] a flare hisses into the dark.")
end

function Run:use_light(dt)
	self.player.fire_cooldown = math.max(0, self.player.fire_cooldown - dt)
	local fire_allowed = self.category ~= "pacifist"
	local propulsion_mode = self.keys.f and self.keys.s -- backward + fire = propulsion
	if fire_allowed and self.keys.f and self.player.fire_cooldown <= 0 and self.player.light_charge > 4 then
		self.player.light_charge = math.max(0, self.player.light_charge - 24 * dt)
		self.player.fire_cooldown = 0.04
		if propulsion_mode then
			self.momentum:set_propulsion(4.0)
			self.stats.propulsions = (self.stats.propulsions or 0) + 1
		end
		local damage_mult = propulsion_mode and 0.5 or 1.0
		self:try_damage_pillars_in_cone(4.0, math.rad(22), 18 * dt * damage_mult)
		if not (self.category == "pacifist") then
			for _, enemy in ipairs(self.world.enemies) do
				if enemy.alive ~= false and weapon_cone_hit(self, enemy) then
					enemy.health = enemy.health - 28 * dt * damage_mult
					enemy.alert_time = 2.2
					if enemy.kind == "leech" then
						enemy.retreat_time = 1.1
					end
					if enemy.health <= 0 then
						self:handle_enemy_death(enemy)
						self:push_message(enemy.kind .. " burned away.")
					end
				end
			end
		end
	else
		local recovery = 10 + math.min(3, self.player.inventory_torches) * 2
		if self.mutators.embers then
			recovery = recovery + 3
		end
		recovery = recovery * self.relics:get_value("light_recovery_mult", 1.0) * self.sanity:get_effects().light_recovery_mult
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
		flare.boost_window = math.max(0, (flare.boost_window or 0) - dt)
		if not flare.boosted and flare.boost_window > 0 and util.distance(self.player.x, self.player.y, flare.x, flare.y) <= 0.78 then
			flare.boosted = true
			self.player.speed_boost_time = math.max(self.player.speed_boost_time, 1.25)
			self.player.speed_boost_mult = math.max(self.player.speed_boost_mult, 1.38)
			self.player.flare_feedback_time = 0.5
			self.stats.flare_boosts = self.stats.flare_boosts + 1
			local node = self:find_route_node("flare_line", flare.cell.x, flare.cell.y, { "path", "checkpoints" })
			if node then
				self.player.flare_line_window = math.max(self.player.flare_line_window, node.boost_window or flare.boost_window or 1.1)
				self.player.speed_boost_mult = math.max(self.player.speed_boost_mult, node.speed_mult or 1.46)
			else
				self.player.flare_line_window = math.max(self.player.flare_line_window, flare.boost_window or 0)
			end
			self:push_message("[boost] the flare slings you ahead.")
		end
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

function Run:update_sanity(dt)
	local cell_x, cell_y = World.world_to_cell(self.player.x, self.player.y)
	local tags = self:get_current_tags()
	local dark_lane = tags.dark_lane and self:find_route_node("dark_lane", cell_x, cell_y, { "path" }) or nil
	local status = self.sanity:update(dt, {
		blackout_time = self.blackout_time,
		in_safe_zone = tags.safe_zone == true,
		in_dark_zone = tags.dark_zone == true or self.boss.fog_active == true,
		in_cursed_zone = tags.cursed_zone == true,
		enemy_pressure = self:get_enemy_pressure(),
		drain_mult = self.relics:get_value("sanity_drain_mult", 1.0) * (dark_lane and dark_lane.drain_mult or (tags.dark_lane and 1.2 or 1.0)),
	})
	self.sanity_status = status
end

function Run:update_time_attack(dt)
	if self.mode ~= "time_attack" or self.completed then
		self.time_attack_enemy_mult = 1.0
		return
	end

	self.time_attack_elapsed = self.time_attack_elapsed + dt
	local level = Challenges.time_attack_level(self.time_attack_elapsed)
	if level > self.time_attack_level then
		self.time_attack_level = level
		self:push_message(string.format("[timer] pressure rises to level %d.", level))
	end
	self.time_attack_enemy_mult = Challenges.time_attack_enemy_mult(self.time_attack_level)
	self.time_attack_spawn_timer = self.time_attack_spawn_timer - dt
	if self.time_attack_spawn_timer <= 0 then
		local spawn_kind = self.time_attack_level >= 4 and "rusher" or (self.time_attack_level >= 2 and "leech" or "stalker")
		local origin = self.floor == self.total_floors and self.world.bossRoom and self.world.bossRoom.center or self:current_objective_cell()
		if origin then
			self:spawn_enemy(spawn_kind, origin, self.time_attack_level >= 5 and "swift" or nil)
		end
		self.time_attack_spawn_timer = Challenges.time_attack_spawn_interval(self.time_attack_level)
	end
end

function Run:update_boss(dt)
	if self.floor ~= self.total_floors or not self.boss.active or self.completed then
		return
	end
	local boss_challenge_mult = Challenges.time_attack_boss_mult(self.time_attack_level or 0)
	local weaken_factor = 1 + (self.boss.weakened or 0) * (self.mode == "sprint" and 0.24 or 0.16)
	local route = self.boss.route
	if route and route.bonus_active then
		weaken_factor = weaken_factor * (1 / math.max(0.45, route.hazard_mult or 0.76))
	end

	-- phase determination: 5 phases
	local prev_phase = self.boss.phase
	local umbra = nil
	for _, e in ipairs(self.world.enemies) do
		if e.kind == "umbra" and e.alive ~= false then umbra = e; break end
	end
	local anchors_lit = self.stats.anchors_lit
	local total_anchors = #self.world.anchors
	if anchors_lit >= total_anchors and umbra and umbra.health < 500 then
		self.boss.phase = 5
	elseif anchors_lit >= total_anchors then
		self.boss.phase = 4
	elseif anchors_lit >= math.max(2, total_anchors - 1) then
		self.boss.phase = 3
	elseif anchors_lit >= 1 then
		self.boss.phase = 2
	else
		self.boss.phase = 1
	end
	if self.boss.phase ~= prev_phase then
		self.events:emit("boss_phase_changed", { phase = self.boss.phase })
	end

	self.boss.pulse_timer = self.boss.pulse_timer - dt
	self.boss.summon_timer = self.boss.summon_timer - dt
	self.boss.wall_timer = self.boss.wall_timer - dt
	self.boss.beam_timer = (self.boss.beam_timer or 0) - dt
	self.boss.beam_angle = (self.boss.beam_angle or 0) + dt * 0.8
	self.boss.darkness_pulse_timer = (self.boss.darkness_pulse_timer or 3.0) - dt
	self.boss.fog_timer = (self.boss.fog_timer or 5.0) - dt

	local player_cell = { x = select(1, World.world_to_cell(self.player.x, self.player.y)), y = select(2, World.world_to_cell(self.player.x, self.player.y)) }

	-- pulse attack (all phases)
	if self.boss.pulse_timer <= 0 then
		for _, offset in ipairs({
			{ x = 0, y = 0 }, { x = 1, y = 0 }, { x = -1, y = 0 }, { x = 0, y = 1 }, { x = 0, y = -1 },
		}) do
			local cell = { x = player_cell.x + offset.x, y = player_cell.y + offset.y }
			if World.is_walkable(self.world, cell.x, cell.y) then
				self:queue_hazard(cell, 0.85, 1.4, 1)
			end
		end
		self.blackout_time = math.max(self.blackout_time, 1.0 + self.boss.phase * 0.4)
		self.sanity:apply(6 + self.boss.phase * 1.5)
		self.boss.pulse_timer = math.max(1.2, ((4.3 - self.boss.phase * 0.8) * weaken_factor) / boss_challenge_mult)
		self:push_message("[pulse] Umbra exhales through the room.")
	end

	-- rotating beam (phase 2+)
	if self.boss.phase >= 2 and self.boss.beam_timer <= 0 and self.world.bossRoom then
		local center = self.world.bossRoom.center
		local cx, cy = center.x, center.y
		local cos_a = math.cos(self.boss.beam_angle)
		local sin_a = math.sin(self.boss.beam_angle)
		for dist = 1, 8 do
			local bx = cx + math.floor(cos_a * dist + 0.5)
			local by = cy + math.floor(sin_a * dist + 0.5)
			if World.is_walkable(self.world, bx, by) then
				self:queue_hazard({ x = bx, y = by }, 0.6, 1.0, 1)
			end
		end
		self.boss.beam_timer = math.max(0.8, ((2.5 - self.boss.phase * 0.3) * weaken_factor) / boss_challenge_mult)
	end

	-- wall hazards (phase 2+)
	if self.boss.phase >= 2 and self.boss.wall_timer <= 0 then
		for _, cell in ipairs(self.world.bossRoom.cells) do
			if cell.x == player_cell.x or (self.boss.phase >= 3 and cell.y == player_cell.y) then
				self:queue_hazard({ x = cell.x, y = cell.y }, 0.95, 1.5, 1)
			end
		end
		self.boss.wall_timer = math.max(1.8, ((5.0 - self.boss.phase * 0.8) * weaken_factor) / boss_challenge_mult)
		self:push_message("[crack] the chamber folds into harsher geometry.")
	end

	-- fog (phase 3+)
	if self.boss.phase >= 3 and self.boss.fog_timer <= 0 then
		self.boss.fog_active = true
		self.boss.fog_duration = 4.0
		self.boss.fog_timer = math.max(4.0, ((8.0 - self.boss.phase) * weaken_factor) / boss_challenge_mult)
		self:push_message("[smother] light-dampening fog fills the arena.")
	end
	if self.boss.fog_active then
		self.boss.fog_duration = self.boss.fog_duration - dt
		self.blackout_time = math.max(self.blackout_time, 0.5)
		self.sanity:apply(1.4 * dt)
		if self.boss.fog_duration <= 0 then
			self.boss.fog_active = false
		end
	end

	-- darkness pulses (phase 4+)
	if self.boss.phase >= 4 and self.boss.darkness_pulse_timer <= 0 then
		self.blackout_time = math.max(self.blackout_time, 1.0)
		self.sanity:apply(10)
		self.boss.darkness_pulse_timer = (2.0 * weaken_factor) / boss_challenge_mult
	end

	-- summon waves
	if self.boss.summon_timer <= 0 then
		if self.boss.phase == 1 then
			self:spawn_enemy("stalker", self.world.bossRoom.center)
		elseif self.boss.phase == 2 then
			self:spawn_enemy("sentry", self.world.bossRoom.center)
			self:spawn_enemy("leech", self.world.bossRoom.center)
		elseif self.boss.phase == 3 then
			self:spawn_enemy("rusher", self.world.bossRoom.center, "swift")
			self:spawn_enemy("leech", self.world.bossRoom.center)
			self:spawn_enemy("rusher", self.world.bossRoom.center)
			self:spawn_enemy("leech", self.world.bossRoom.center)
		elseif self.boss.phase >= 4 then
			self:spawn_enemy("rusher", self.world.bossRoom.center, "armored")
			self:spawn_enemy("leech", self.world.bossRoom.center, "cursed")
			self:spawn_enemy("stalker", self.world.bossRoom.center, "swift")
		end
		self.boss.summon_timer = math.max(1.5, ((5.0 - self.boss.phase * 0.8) * weaken_factor) / boss_challenge_mult)
	end

	-- phase 5: Umbra becomes aggressive (handled in AI via context)
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
	if self.paused then return nil end
	local timer_active = (not self.timer_armed) or self.timer_started
	if timer_active then
		self.clock = self.clock + dt
	end
	self.damage_flash = math.max(0, self.damage_flash - dt)
	self.blackout_time = math.max(0, self.blackout_time - dt)
	self.alarm_time = math.max(0, self.alarm_time - dt)
	self.guidance_time = math.max(0, self.guidance_time - dt)
	self.player.invulnerability_time = math.max(0, self.player.invulnerability_time - dt)
	self.player.speed_boost_time = math.max(0, self.player.speed_boost_time - dt)
	self.player.speed_boost_mult = self.player.speed_boost_time > 0 and self.player.speed_boost_mult or 1.0
	self.player.dash_time = math.max(0, self.player.dash_time - dt)
	self.player.dash_cooldown = math.max(0, self.player.dash_cooldown - dt)
	self.player.flare_line_window = math.max(0, self.player.flare_line_window - dt)
	self.player.dash_feedback_time = math.max(0, self.player.dash_feedback_time - dt)
	self.player.flare_feedback_time = math.max(0, self.player.flare_feedback_time - dt)
	if self.guidance_time <= 0 then
		self.guidance_cells = {}
	end
	if self.keys.r then
		self.restart_hold_time = self.restart_hold_time + dt
		if self.settings.runner_restart_confirmation ~= false and self.restart_hold_time >= 0.55 then
			self.restart_requested = true
			self.restart_reason = "hold_restart"
		end
	else
		self.restart_hold_time = 0
	end

	if not timer_active then
		self.audio:set_listener(self.player.x, self.player.y, self.player.angle)
		self.audio:update(dt)
		self.fx:update(dt)
		return nil
	end

	self:update_time_attack(dt)
	self.stealth:update(dt, self.keys, self.keys.f, self.is_moving)
	self:update_player(dt)
	self:update_sanity(dt)
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

	self:update_ghost_compare()
	self:update_practice_goal()
	self:reveal_nearby()
	self.audio:set_listener(self.player.x, self.player.y, self.player.angle)
	self.audio:update(dt)
	self.fx:update(dt)

	if self.player.health <= 0 then
		return "dead"
	end
	if self.completed then
		if not self.finish_splits_recorded then
			self.stats.floors_cleared = math.max(self.stats.floors_cleared, self.floor)
			self:record_split(string.format("floor_%d_clear", self.floor), string.format("Floor %d Clear", self.floor), self.floor)
			if self.floor == self.total_floors then
				self:record_split("boss_kill", "Boss Kill", self.floor)
			end
			self:record_split("run_finish", "Run Finish", self.floor)
			self.finish_splits_recorded = true
		end
		return "victory"
	end
	return nil
end

function Run:draw()
	if not Renderer then
		Renderer = require("src.render.renderer")
	end
	self.renderer = self.renderer or Renderer.new(self.settings)
	if self.floor < self.total_floors then
		self.objective_text = self.player.collected_torches < self.player.torch_goal
			and string.format("Objective: recover %d more torches.", self.player.torch_goal - self.player.collected_torches)
			or "Objective: reach the exit."
	else
		local route_target = self:get_boss_route_target()
		if route_target and self.mode == "sprint" and (route_target.type == "pillar" or self.player.inventory_torches > 0) then
			self.objective_text = string.format("Objective: %s.", route_target.label)
		else
			self.objective_text = string.format("Objective: light %d remaining anchors.", #self.world.anchors - self.stats.anchors_lit)
		end
	end
	local view_distortion = self.sanity:get_effects().view_distortion
	self.camera = {
		x = self.player.x,
		y = self.player.y,
		angle = self.player.angle + math.sin(self.clock * 1.6) * view_distortion * 0.05,
		height = self.momentum:is_sliding() and 0.35 or self.player.height,
	}
	self.fx:apply_camera(self.camera, self.is_moving, self.momentum)
	self.renderer:draw(self)
	if self.paused then
		self.renderer.hud:draw_pause(self, love.graphics)
	end
end

function Run:keypressed(key)
	if self.paused then
		if key == "escape" then
			self.paused = false
			self.renderer.hud.paused = false
		elseif key == "r" then
			self.restart_requested = true
			self.restart_reason = "pause_restart"
		elseif key == "v" or key == "s" then
			self.replay_save_requested = true
		else
			self.renderer.hud:pause_keypressed(key)
		end
		return
	end
	self.keys[key] = true
	if self.timer_armed and not self.timer_started then
		local timer_reason = nil
		if key == "w" or key == "a" or key == "s" or key == "d" or key == "q" or key == "c" then
			timer_reason = "movement"
		elseif key == "space" or key == "e" or key == "f" or key == "g" or key == "lshift" or key == "rshift" or key == "1" or key == "2" or key == "3" then
			timer_reason = "action"
		end
		if timer_reason then
			self:begin_timer(timer_reason)
		end
	end
	if key == "space" then
		self.momentum:request_jump()
	elseif key == "e" then
		self.pending_interact = true
	elseif key == "1" then
		self:use_consumable(1)
	elseif key == "2" then
		self:use_consumable(2)
	elseif key == "3" then
		self:use_consumable(3)
	elseif key == "g" then
		self.pending_flare = true
	elseif key == "tab" then
		self.automap_enabled = not self.automap_enabled
	elseif key == "escape" then
		self.paused = true
		self.renderer.hud.paused = true
	elseif key == "r" and self.settings.runner_restart_confirmation == false then
		self.restart_requested = true
		self.restart_reason = "tap_restart"
	end
end

function Run:keyreleased(key)
	self.keys[key] = nil
	if key == "r" then
		self.restart_hold_time = 0
	end
	if key == "lshift" or key == "rshift" then
		self:release_burst()
	end
end

return Run
