local Run = require("src.game.run")
local Settings = require("src.core.settings")
local LoreData = require("src.data.lore")
local Difficulty = require("src.data.difficulty")
local Meta = require("src.game.meta")
local Replay = require("src.game.replay")
local Challenges = require("src.game.challenges")
local Sprint = require("src.game.sprint")
local Build = require("src.core.build")
local util = require("src.core.util")

local App = {}
App.__index = App

local title_items = {
	"start",
	"difficulty",
	"mode",
	"sprint_pack",
	"sprint_ruleset",
	"sprint_seed",
	"practice_target",
	"loadout",
	"flame",
	"progression",
	"replays",
	"quit",
}

local difficulty_cycle = { "apprentice", "stalker", "nightmare" }
local mode_cycle = { "classic", "daily", "time_attack", "sprint" }
local sprint_ruleset_cycle = { "official", "practice" }
local replay_sort_cycle = { "latest", "duration", "mode", "seed" }
local replay_filter_cycle = { "all", "official_sprint", "floor_practice", "drill", "classic", "daily", "time_attack" }

local function cycle_value(values, current, direction)
	local index = 1
	for i, value in ipairs(values) do
		if value == current then
			index = i
			break
		end
	end
	index = index + direction
	if index < 1 then
		index = #values
	elseif index > #values then
		index = 1
	end
	return values[index]
end

local function draw_centered(lg, text, y, width, color)
	lg.setColor(color)
	lg.printf(text, 0, y, width, "center")
end

local function format_time(seconds)
	local minutes = math.floor((seconds or 0) / 60)
	local secs = (seconds or 0) - minutes * 60
	return string.format("%02d:%05.2f", minutes, secs)
end

local function format_delta(delta)
	if delta == nil then
		return "--"
	end
	return string.format("%+.2fs", delta)
end

function App.new()
	return setmetatable({
		screen = "title",
		title_index = 1,
		selected_difficulty = "stalker",
		selected_mode = "classic",
		seed = os.time(),
		run = nil,
		last_result = nil,
		last_summary = nil,
		last_run_config = nil,
		last_sprint_record = nil,
		settings = Settings.load(),
		meta = nil,
		replay_entries = {},
		selected_replay_index = 1,
		drill_entries = {},
		selected_drill_index = 1,
		drill_source = nil,
		replay_sort = "latest",
		replay_filter_mode = "all",
		replay_pb_only = false,
		selected_mutators = {
			embers = false,
			echoes = false,
			onslaught = false,
			ironman = false,
			blacklight = false,
		},
	}, App)
end

function App:load(_args)
	self.meta = Meta.new(self.settings)
	self.selected_mode = self.settings.selected_mode or "classic"
	if not self.settings.selected_sprint_practice_target and self.settings.selected_sprint_practice_floor then
		self.settings.selected_sprint_practice_target = string.format("floor:%d", self.settings.selected_sprint_practice_floor)
	end
	self.settings.selected_sprint_pack_id = self.settings.selected_sprint_pack_id or Sprint.get_default_pack_id()
	self.settings.selected_sprint_seed_id = self.settings.selected_sprint_seed_id or Sprint.get_seed_by_index(self.settings.selected_sprint_pack_id, 1).id
	self.settings.selected_sprint_practice_target = Sprint.normalize_practice_target(
		self.settings.selected_sprint_pack_id,
		self.settings.selected_sprint_seed_id,
		self.settings.selected_sprint_practice_target or "floor:1"
	)
	self.seed = os.time()
	Replay.init()
	self:refresh_replays()
end

function App:save_settings()
	self.settings.selected_mode = self.selected_mode
	if self.meta then
		self.meta:save(self.settings)
	end
	Settings.save(self.settings)
end

function App:get_available_loadouts()
	return self.meta and self.meta:get_available_loadouts() or {
		{ id = "default", label = "Descender", desc = "Standard descent loadout.", unlocked = true },
	}
end

function App:get_available_flames()
	return self.meta and self.meta:get_available_flames() or {
		{ id = "amber", label = "Amber Flame", desc = "Default warm survival flame.", unlocked = true },
	}
end

function App:is_sprint_mode()
	return self.selected_mode == "sprint"
end

function App:is_sprint_official()
	return self.selected_mode == "sprint" and (self.settings.selected_sprint_ruleset or "official") == "official"
end

function App:get_sprint_pack()
	return Sprint.get_pack(self.settings.selected_sprint_pack_id or Sprint.get_default_pack_id())
end

function App:get_practice_target_id()
	return Sprint.normalize_practice_target(
		self.settings.selected_sprint_pack_id or Sprint.get_default_pack_id(),
		self.settings.selected_sprint_seed_id or "ember_arc",
		self.settings.selected_sprint_practice_target or "floor:1"
	)
end

function App:get_practice_target_label(pack_id, seed_id, target_id)
	return Sprint.target_label(pack_id or self.settings.selected_sprint_pack_id, seed_id or self.settings.selected_sprint_seed_id, target_id or self:get_practice_target_id())
end

function App:get_effective_config()
	if self.selected_mode == "daily" then
		local profile = Challenges.daily_profile()
		return {
			mode = "daily",
			daily_label = profile.label,
			difficulty = profile.difficulty,
			seed = profile.seed,
			mutators = profile.mutators,
			loadout = profile.loadout,
			flame_color = profile.flame_color,
			official_record_eligible = false,
		}
	end

	if self.selected_mode == "sprint" then
		local pack_id = self.settings.selected_sprint_pack_id or Sprint.get_default_pack_id()
		local ruleset = self.settings.selected_sprint_ruleset or "official"
		local selected_seed_id = self.settings.selected_sprint_seed_id or Sprint.get_seed_by_index(pack_id, 1).id
		if ruleset == "official" then
			if selected_seed_id == "random" then
				selected_seed_id = Sprint.get_seed_by_index(pack_id, 1).id
				self.settings.selected_sprint_seed_id = selected_seed_id
			end
			local seed_entry = Sprint.get_seed(pack_id, selected_seed_id)
			return {
				mode = "sprint",
				sprint_ruleset = "official",
				difficulty = self.selected_difficulty,
				seed = seed_entry.seed,
				sprint_seed_pack_id = pack_id,
				sprint_seed_id = seed_entry.id,
				pack_version = Sprint.get_pack_version(pack_id),
				category_key = Sprint.category_key(self.selected_difficulty, pack_id, seed_entry.id),
				mutators = {},
				loadout = "default",
				flame_color = self.settings.selected_flame_color or "amber",
				practice_target = nil,
				start_floor = 1,
				official_record_eligible = true,
			}
		end

		local practice_target = Sprint.normalize_practice_target(pack_id, selected_seed_id, self.settings.selected_sprint_practice_target or "floor:1")
		local practice_info = Sprint.get_practice_target(pack_id, selected_seed_id, practice_target, self.selected_difficulty)
		local seed = self.seed
		local seed_pack_id = nil
		local seed_id = nil
		if selected_seed_id ~= "random" then
			local seed_entry = Sprint.get_seed(pack_id, selected_seed_id)
			seed = seed_entry.seed
			seed_pack_id = pack_id
			seed_id = seed_entry.id
		end
		return {
			mode = "sprint",
			sprint_ruleset = "practice",
			difficulty = self.selected_difficulty,
			seed = seed,
			sprint_seed_pack_id = seed_pack_id,
			sprint_seed_id = seed_id,
			pack_version = seed_pack_id and Sprint.get_pack_version(seed_pack_id) or "",
			mutators = util.deepcopy(self.selected_mutators),
			loadout = self.settings.selected_loadout or "default",
			flame_color = self.settings.selected_flame_color or "amber",
			practice_target = practice_info.id,
			practice_target_label = practice_info.label,
			start_floor = practice_info.floor or 1,
			official_record_eligible = false,
		}
	end

	return {
		mode = self.selected_mode,
		difficulty = self.selected_difficulty,
		seed = self.seed,
		mutators = util.deepcopy(self.selected_mutators),
		loadout = self.settings.selected_loadout or "default",
		flame_color = self.settings.selected_flame_color or "amber",
		official_record_eligible = false,
	}
end

function App:get_preview()
	local config = self:get_effective_config()
	local preview = Difficulty.build(config.difficulty, 1, config.mutators)
	local hp = preview.player_health - (config.mutators.blacklight and 2 or 0)
	if config.mutators.ironman then
		hp = 1
	end
	return {
		hp = math.max(1, hp),
		view_distance = preview.view_distance,
		threat_budget = preview.threat_budget,
		torch_goal = preview.torch_goal,
		flares = preview.flare_count + (config.loadout == "scout" and 2 or 0),
	}
end

function App:get_sprint_record(config)
	if not config or config.mode ~= "sprint" or config.sprint_ruleset ~= "official" or not config.category_key then
		return nil
	end
	return self.settings.sprint_records[config.category_key]
end

function App:build_ghost_compare(config)
	local record = self:get_sprint_record(config)
	if not record or not record.pb_replay then
		return nil, nil, nil, nil
	end
	local replay = Replay.inspect(record.pb_replay)
	if not replay or replay.metadata.category_key ~= config.category_key then
		return nil, nil, nil, nil
	end
	return {
		frames = replay.ghost_frames or {},
	}, record.best_time, record.best_splits or {}, record.best_possible_time
end

function App:start_run(config)
	config = util.deepcopy(config or self:get_effective_config())
	self.seed = config.seed
	self.last_sprint_record = nil
	self.last_run_config = util.deepcopy(config)
	self.last_run_config.replay_mode = nil

	local ghost_compare, pb_time, pb_splits, best_possible_time = nil, nil, nil, nil
	if not config.replay_mode then
		ghost_compare, pb_time, pb_splits, best_possible_time = self:build_ghost_compare(config)
	end

	self.run = Run.new(config.difficulty, config.seed, config.mutators, self.settings, {
		mode = config.mode,
		daily_label = config.daily_label,
		sprint_ruleset = config.sprint_ruleset,
		sprint_seed_pack_id = config.sprint_seed_pack_id,
		sprint_seed_id = config.sprint_seed_id,
		pack_version = config.pack_version,
		practice_target = config.practice_target,
		start_floor = config.start_floor or 1,
		category_key = config.category_key,
		loadout = config.loadout,
		flame_color = config.flame_color,
		replay_mode = config.replay_mode == true,
		official_record_eligible = config.official_record_eligible == true and config.replay_mode ~= true,
		ghost_compare = ghost_compare,
		pb_total_time = pb_time,
		pb_splits = pb_splits,
		best_possible_time = best_possible_time,
		medal_targets = config.mode == "sprint" and config.sprint_ruleset == "official"
			and Sprint.get_medal_targets(config.sprint_seed_pack_id, config.sprint_seed_id, config.difficulty)
			or nil,
	})

	if not config.replay_mode then
		Replay.start_recording(config.seed, config.difficulty, {
			mode = config.mode,
			daily_label = config.daily_label,
			sprint_ruleset = config.sprint_ruleset,
			sprint_seed_pack_id = config.sprint_seed_pack_id,
			sprint_seed_id = config.sprint_seed_id,
			category_key = config.category_key,
			pack_version = config.pack_version,
			mutators = config.mutators,
			loadout = config.loadout,
			flame_color = config.flame_color,
			practice_target = config.practice_target,
			start_floor = config.start_floor or 1,
			official_record_eligible = config.official_record_eligible == true,
		})
		Replay.set_metadata({
			pb = false,
			restart_reason = "",
			category_key = config.category_key or "",
			seed_pack_id = config.sprint_seed_pack_id or "",
			seed_id = config.sprint_seed_id or "",
			ruleset = config.sprint_ruleset or "",
			medal = "",
			build_id = Build.get_id(),
			pack_version = config.pack_version or "",
			practice_target = config.practice_target or "",
			timer_start_reason = "",
		})
	end
	self.screen = "play"
end

function App:return_to_title()
	Replay.stop_recording()
	Replay.stop_playback()
	self.run = nil
	self.screen = "title"
	self:refresh_replays()
end

local function replay_bucket(replay)
	local mode = replay.context.mode or "classic"
	if mode ~= "sprint" then
		return mode
	end
	if replay.context.sprint_ruleset == "official" then
		return "official_sprint"
	end
	local target = replay.context.practice_target or ""
	if target:match("^drill:") then
		return "drill"
	end
	return "floor_practice"
end

function App:refresh_replays()
	local entries = {}
	for _, file in ipairs(Replay.list_replays()) do
		local replay = Replay.inspect(file)
		if replay then
			local mode = replay_bucket(replay)
			local pb = replay.metadata.pb == true
			if (self.replay_filter_mode == "all" or mode == self.replay_filter_mode)
				and (not self.replay_pb_only or pb) then
				entries[#entries + 1] = {
					file = file,
					replay = replay,
					mode = mode,
					duration = replay.metadata.duration or 0,
					pb = pb,
				}
			end
		end
	end

	table.sort(entries, function(left, right)
		if self.replay_sort == "duration" then
			if left.duration == right.duration then
				return left.file > right.file
			end
			return left.duration < right.duration
		elseif self.replay_sort == "mode" then
			if left.mode == right.mode then
				return left.duration < right.duration
			end
			return left.mode < right.mode
		elseif self.replay_sort == "seed" then
			if left.replay.seed == right.replay.seed then
				return left.duration < right.duration
			end
			return (left.replay.seed or 0) < (right.replay.seed or 0)
		end
		return left.file > right.file
	end)

	self.replay_entries = entries
	if self.selected_replay_index > #entries then
		self.selected_replay_index = #entries
	end
	if self.selected_replay_index < 1 then
		self.selected_replay_index = 1
	end
end

function App:save_replay_snapshot(reason, filename, extra_metadata)
	if not self.run or self.run.replay_mode or not Replay.has_data() then
		return false
	end
	local summary = self.run:summary()
	Replay.set_summary(summary)
	Replay.set_metadata({
		pb = extra_metadata and extra_metadata.pb == true or false,
		restart_reason = reason or "",
		category_key = summary.category_key or "",
		seed_pack_id = summary.sprint_seed_pack_id or "",
		seed_id = summary.sprint_seed_id or "",
		ruleset = summary.sprint_ruleset or "",
		medal = summary.medal or "",
		build_id = Build.get_id(),
		pack_version = summary.pack_version or "",
		practice_target = summary.practice_target or "",
		timer_start_reason = summary.timer_start_reason or "",
		best_possible_time = summary.best_possible_time or 0,
		replay_file = filename or "",
		tech_usage = summary.tech_usage or {},
		route_events = summary.route_events or {},
		gold_splits = summary.gold_splits or {},
		projected_saves = summary.projected_saves or {},
	})
	local ok = Replay.save(filename)
	if ok then
		self:refresh_replays()
		if self.run and not (extra_metadata and extra_metadata.quiet) then
			self.run:push_message("Replay saved.")
			self.run.replay_save_requested = false
		end
	end
	return ok
end

function App:record_result(outcome)
	self.last_summary = self.run:summary()
	self.last_summary.outcome = outcome
	self.last_result = outcome
	self.screen = outcome
	self.last_sprint_record = nil

	if self.meta and not self.run.replay_mode then
		self.meta:record_run(self.last_summary)
		self.meta:save(self.settings)
	end

	if outcome == "victory" and not self.run.replay_mode then
		if self.last_summary.mode == "daily" and self.last_summary.daily_label then
			local current = self.settings.daily_records[self.last_summary.daily_label]
			if current == nil or self.last_summary.duration < current then
				self.settings.daily_records[self.last_summary.daily_label] = self.last_summary.duration
			end
		elseif self.last_summary.mode == "time_attack" then
			local key = self.last_run_config and self.last_run_config.difficulty or self.selected_difficulty
			local current = self.settings.time_attack_records[key]
			if current == nil or self.last_summary.duration < current then
				self.settings.time_attack_records[key] = self.last_summary.duration
			end
		elseif self.last_summary.mode == "sprint" and self.last_summary.sprint_ruleset == "official" then
			local finish_replay = Replay.result_filename(self.last_summary.category_key, os.time())
			if not self:save_replay_snapshot("official_finish", finish_replay, { pb = false, quiet = true }) then
				finish_replay = nil
			end
			local records, sprint_result = Sprint.update_record(self.settings.sprint_records, self.last_summary)
			self.settings.sprint_records = records
			local pb_name = nil
			if sprint_result.new_pb and self.settings.runner_auto_save_pb_replay ~= false then
				pb_name = Replay.pb_filename(sprint_result.category_key)
				if self:save_replay_snapshot("pb_finish", pb_name, { pb = true, quiet = true }) then
					local with_replay, replay_result = Sprint.update_record(self.settings.sprint_records, self.last_summary, pb_name)
					self.settings.sprint_records = with_replay
					sprint_result = replay_result
				end
			end
			self.last_sprint_record = sprint_result
			self:export_sprint_summary(self.last_summary, sprint_result, finish_replay)
		elseif self.last_summary.mode == "sprint" and self.last_summary.sprint_ruleset == "practice" then
			local records = self.settings.sprint_practice_records or {}
			local updated_records = Sprint.update_practice_record(records, self.last_summary)
			self.settings.sprint_practice_records = updated_records
		end
	end

	self:save_settings()
	Replay.stop_recording()
	Replay.stop_playback()
	self:refresh_replays()
end

function App:start_selected_replay()
	local entry = self.replay_entries[self.selected_replay_index]
	if not entry then
		return false
	end
	if not Replay.load(entry.file) then
		return false
	end
	local replay = entry.replay
	local context = replay.context or {}
	self:start_run({
		mode = context.mode or "classic",
		daily_label = context.daily_label,
		sprint_ruleset = context.sprint_ruleset,
		sprint_seed_pack_id = context.sprint_seed_pack_id,
		sprint_seed_id = context.sprint_seed_id,
		pack_version = context.pack_version or replay.metadata.pack_version,
		category_key = replay.metadata.category_key or context.category_key,
		difficulty = replay.difficulty or "stalker",
		seed = replay.seed,
		mutators = context.mutators or {},
		loadout = context.loadout or "default",
		flame_color = context.flame_color or "amber",
		practice_target = context.practice_target,
		start_floor = context.start_floor or 1,
		official_record_eligible = false,
		replay_mode = true,
	})
	return Replay.start_playback()
end

function App:start_pb_replay()
	local config = self.last_run_config or self:get_effective_config()
	local record = self:get_sprint_record(config)
	if not record or not record.pb_replay then
		return false
	end
	local replay = Replay.inspect(record.pb_replay)
	if not replay or not Replay.load(record.pb_replay) then
		return false
	end
	local context = replay.context or {}
	self:start_run({
		mode = context.mode or "classic",
		daily_label = context.daily_label,
		sprint_ruleset = context.sprint_ruleset,
		sprint_seed_pack_id = context.sprint_seed_pack_id,
		sprint_seed_id = context.sprint_seed_id,
		pack_version = context.pack_version or replay.metadata.pack_version,
		category_key = replay.metadata.category_key or context.category_key,
		difficulty = replay.difficulty or "stalker",
		seed = replay.seed,
		mutators = context.mutators or {},
		loadout = context.loadout or "default",
		flame_color = context.flame_color or "amber",
		practice_target = context.practice_target,
		start_floor = context.start_floor or 1,
		official_record_eligible = false,
		replay_mode = true,
	})
	return Replay.start_playback()
end

function App:start_practice_target(target_id)
	local source = util.deepcopy(self.last_run_config or self:get_effective_config())
	if source.mode ~= "sprint" then
		return false
	end
	source.sprint_ruleset = "practice"
	source.official_record_eligible = false
	source.practice_target = target_id
	local practice_info = Sprint.get_practice_target(source.sprint_seed_pack_id, source.sprint_seed_id, target_id, source.difficulty)
	source.practice_target_label = practice_info.label
	source.start_floor = practice_info.floor or 1
	source.replay_mode = false
	if source.sprint_seed_id then
		local seed_entry = Sprint.get_seed(source.sprint_seed_pack_id or Sprint.get_default_pack_id(), source.sprint_seed_id)
		source.seed = seed_entry.seed
	else
		source.seed = self.seed
	end
	self:start_run(source)
	return true
end

function App:start_practice_floor(floor)
	return self:start_practice_target(string.format("floor:%d", floor))
end

function App:refresh_drill_entries(source_config)
	local config = source_config or self.last_run_config or self:get_effective_config()
	if not config or config.mode ~= "sprint" then
		self.drill_entries = {}
		self.selected_drill_index = 1
		return
	end
	local pack_id = config.sprint_seed_pack_id or self.settings.selected_sprint_pack_id or Sprint.get_default_pack_id()
	local seed_id = config.sprint_seed_id or self.settings.selected_sprint_seed_id
	self.drill_source = {
		pack_id = pack_id,
		seed_id = seed_id,
		difficulty = config.difficulty or self.selected_difficulty,
	}
	self.drill_entries = Sprint.list_practice_targets(pack_id, seed_id)
	self.selected_drill_index = 1
	for index, target in ipairs(self.drill_entries) do
		if target.id == (config.practice_target or self:get_practice_target_id()) then
			self.selected_drill_index = index
			break
		end
	end
end

function App:open_drill_browser(source_config)
	self:refresh_drill_entries(source_config)
	self.screen = "drills"
end

function App:start_selected_drill_target()
	local entry = self.drill_entries[self.selected_drill_index]
	if not entry then
		return false
	end
	return self:start_practice_target(entry.id)
end

function App:export_sprint_summary(summary, sprint_result, replay_filename)
	if not summary or summary.mode ~= "sprint" or summary.sprint_ruleset ~= "official" then
		return false
	end
	local build_id = Build.get_id()
	local export_base = Replay.get_export_dir() .. "/" .. Replay.export_basename(summary.category_key, os.time())
	local payload = {
		build_id = build_id,
		category_key = summary.category_key or "",
		pack_version = summary.pack_version or "",
		seed = summary.seed or 0,
		seed_pack_id = summary.sprint_seed_pack_id or "",
		seed_id = summary.sprint_seed_id or "",
		ruleset = summary.sprint_ruleset or "",
		difficulty = summary.difficulty_id or "",
		duration = summary.duration or 0,
		medal = summary.medal or "",
		best_possible_time = (sprint_result and sprint_result.best_possible_time) or summary.best_possible_time or 0,
		timer_start_reason = summary.timer_start_reason or "",
		replay_file = replay_filename or "",
		gold_splits = util.deepcopy((sprint_result and sprint_result.gold_splits) or summary.gold_splits or {}),
		projected_saves = util.deepcopy((sprint_result and sprint_result.projected_saves) or summary.projected_saves or {}),
		splits = util.deepcopy(summary.splits or {}),
	}
	local lines = {
		"build_id=" .. tostring(payload.build_id),
		"category_key=" .. tostring(payload.category_key),
		"pack_version=" .. tostring(payload.pack_version),
		"seed=" .. tostring(payload.seed),
		"seed_pack_id=" .. tostring(payload.seed_pack_id),
		"seed_id=" .. tostring(payload.seed_id),
		"ruleset=" .. tostring(payload.ruleset),
		"difficulty=" .. tostring(payload.difficulty),
		"duration=" .. tostring(payload.duration),
		"medal=" .. tostring(payload.medal),
		"best_possible_time=" .. tostring(payload.best_possible_time),
		"timer_start_reason=" .. tostring(payload.timer_start_reason),
		"replay_file=" .. tostring(payload.replay_file),
	}
	for _, split in ipairs(payload.splits) do
		lines[#lines + 1] = string.format("split:%s=%.4f", split.id, split.time or 0)
	end
	for _, split_id in ipairs(payload.gold_splits) do
		lines[#lines + 1] = "gold_split=" .. tostring(split_id)
	end
	for _, save in ipairs(payload.projected_saves) do
		lines[#lines + 1] = string.format("projected_save:%s=%.4f", save.id or save.label or "segment", save.save or 0)
	end
	local wrote_text = Replay.write_text(export_base .. ".txt", table.concat(lines, "\n") .. "\n")
	local wrote_json = Replay.write_json(export_base .. ".json", payload)
	return wrote_text and wrote_json
end

function App:advance_sprint_seed(step)
	local include_random = (self.settings.selected_sprint_ruleset or "official") == "practice"
	self.settings.selected_sprint_seed_id = Sprint.next_seed_id(self.settings.selected_sprint_pack_id or Sprint.get_default_pack_id(), self.settings.selected_sprint_seed_id or "ember_arc", step or 1, include_random)
	self.settings.selected_sprint_practice_target = Sprint.normalize_practice_target(
		self.settings.selected_sprint_pack_id or Sprint.get_default_pack_id(),
		self.settings.selected_sprint_seed_id,
		self.settings.selected_sprint_practice_target or "floor:1"
	)
	self:save_settings()
end

function App:update(dt)
	if self.screen ~= "play" or not self.run then
		return
	end

	Replay.update(dt)
	if self.run.replay_mode and Replay.is_playing() then
		while true do
			local input = Replay.get_next_input()
			if not input then
				break
			end
			if input.type == "keydown" then
				self.run:keypressed(input.key)
			else
				self.run:keyreleased(input.key)
			end
		end
	end

	local outcome = self.run:update(dt)
	if not self.run.replay_mode and Replay.is_recording() then
		Replay.record_ghost_frame(self.run.clock, self.run.floor, self.run.player.x, self.run.player.y)
	end
	if self.run.restart_requested and self.last_run_config then
		self:start_run(self.last_run_config)
		return
	end
	if self.run.replay_save_requested then
		self:save_replay_snapshot("pause_save")
	end
	if outcome == "dead" then
		if self.last_run_config and self.last_run_config.mode == "sprint" and self.last_run_config.sprint_ruleset == "practice"
			and self.settings.runner_practice_auto_restart == true then
			Replay.stop_recording()
			self:start_run(self.last_run_config)
			return
		end
		self:record_result("dead")
	elseif outcome == "victory" then
		if self.last_run_config and self.last_run_config.mode == "sprint" and self.last_run_config.sprint_ruleset == "practice"
			and self.settings.runner_practice_auto_restart == true then
			local summary = self.run:summary()
			summary.outcome = "victory"
			local updated_records = Sprint.update_practice_record(self.settings.sprint_practice_records or {}, summary)
			self.settings.sprint_practice_records = updated_records
			self:save_settings()
			Replay.stop_recording()
			self:start_run(self.last_run_config)
			return
		end
		self:record_result("victory")
	end
end

function App:draw_title()
	local lg = love.graphics
	local width, height = lg.getDimensions()
	local time = love.timer.getTime()
	local config = self:get_effective_config()
	local preview = self:get_preview()
	local pack = self:get_sprint_pack()
	local title_alpha = self.settings.title_flicker and (math.sin(time * 2.5) * 0.15 + 0.85) or 1.0
	local lore = LoreData.fragments
	local lore_index = math.floor(time / 4) % #lore + 1
	local loadouts = self:get_available_loadouts()
	local flames = self:get_available_flames()
	local mutators = {}
	for name, enabled in pairs(config.mutators or {}) do
		if enabled then
			mutators[#mutators + 1] = name
		end
	end
	table.sort(mutators)

	draw_centered(lg, "KURO", height * 0.09, width, { 0.87, 0.89, 0.95, title_alpha })
	draw_centered(lg, "First-person light survival sprint descent", height * 0.17, width, { 0.45, 0.72, 1.0, 1.0 })
	draw_centered(lg, "\"" .. lore[lore_index].text .. "\"", height * 0.24, width, { 0.4, 0.42, 0.48, 0.7 })

	local sprint_seed_text = "--"
	local practice_target_text = "--"
	if self.selected_mode == "sprint" then
		sprint_seed_text = self.settings.selected_sprint_ruleset == "official"
			and Sprint.get_seed_label(self.settings.selected_sprint_pack_id, config.sprint_seed_id)
			or (self.settings.selected_sprint_seed_id == "random" and "Random Practice" or Sprint.get_seed_label(self.settings.selected_sprint_pack_id, self.settings.selected_sprint_seed_id))
		practice_target_text = self.settings.selected_sprint_ruleset == "practice"
			and self:get_practice_target_label(self.settings.selected_sprint_pack_id, self.settings.selected_sprint_seed_id, self:get_practice_target_id())
			or "--"
	end
	local items = {
		{ key = "start", label = "Start Run" },
		{ key = "difficulty", label = "Difficulty", value = config.difficulty },
		{ key = "mode", label = "Mode", value = config.mode },
		{ key = "sprint_pack", label = "Sprint Pack", value = self.selected_mode == "sprint" and pack.label or "--" },
		{ key = "sprint_ruleset", label = "Sprint Rules", value = self.selected_mode == "sprint" and (self.settings.selected_sprint_ruleset or "official") or "--" },
		{ key = "sprint_seed", label = "Sprint Seed", value = sprint_seed_text },
		{ key = "practice_target", label = "Practice Target", value = practice_target_text },
		{ key = "loadout", label = "Loadout", value = config.loadout },
		{ key = "flame", label = "Flame", value = config.flame_color },
		{ key = "progression", label = "Progression" },
		{ key = "replays", label = "Replays", value = tostring(#self.replay_entries) },
		{ key = "quit", label = "Quit" },
	}

	local start_y = height * 0.33
	for index, item in ipairs(items) do
		local disabled = (item.key == "sprint_ruleset" and self.selected_mode ~= "sprint")
			or (item.key == "sprint_pack" and self.selected_mode ~= "sprint")
			or (item.key == "sprint_seed" and self.selected_mode ~= "sprint")
			or (item.key == "practice_target" and not (self.selected_mode == "sprint" and self.settings.selected_sprint_ruleset == "practice"))
			or (item.key == "loadout" and (self.selected_mode == "daily" or self:is_sprint_official()))
		local text = item.value and string.format("%s: %s", item.label, item.value) or item.label
		local color = disabled and { 0.46, 0.48, 0.52, 1.0 } or (index == self.title_index and { 1.0, 0.93, 0.35, 1.0 } or { 0.82, 0.84, 0.88, 1.0 })
		if index == self.title_index then
			text = "> " .. text .. " <"
		end
		draw_centered(lg, text, start_y + (index - 1) * 24, width, color)
	end

	draw_centered(lg, string.format("HP %d  View %.1f  Threat %d  Torches %d  Flares %d", preview.hp, preview.view_distance, preview.threat_budget, preview.torch_goal, preview.flares), height * 0.67, width, { 0.55, 0.58, 0.64, 1.0 })
	if config.mode == "daily" and config.daily_label then
		local best = self.settings.daily_records[config.daily_label]
		draw_centered(lg, string.format("Daily Seed %d  Best %s", config.seed, best and format_time(best) or "none"), height * 0.72, width, { 0.66, 0.82, 0.96, 1.0 })
	elseif config.mode == "time_attack" then
		local best = self.settings.time_attack_records[config.difficulty]
		draw_centered(lg, string.format("Seed %d  Best %s", config.seed, best and format_time(best) or "none"), height * 0.72, width, { 0.95, 0.8, 0.28, 1.0 })
	elseif config.mode == "sprint" and config.sprint_ruleset == "official" then
		local record = self:get_sprint_record(config)
		local seed = Sprint.get_seed(config.sprint_seed_pack_id, config.sprint_seed_id)
		local best_time = record and record.best_time and format_time(record.best_time) or "none"
		local best_medal = record and (record.best_medal or record.medal) or "none"
		local best_possible = record and record.best_possible_time and format_time(record.best_possible_time) or "--"
		draw_centered(lg, string.format("%s  PB %s  Medal %s  Best Possible %s", seed.label, best_time, best_medal, best_possible), height * 0.72, width, { 0.94, 0.88, 0.42, 1.0 })
	else
		draw_centered(lg, config.mode == "sprint" and string.format("Practice Seed %d  Target %s", config.seed, config.practice_target_label or self:get_practice_target_label()) or ("Seed: " .. tostring(config.seed)), height * 0.72, width, { 0.82, 0.84, 0.88, 1.0 })
	end
	draw_centered(lg, "Mutators: " .. (#mutators > 0 and table.concat(mutators, ", ") or (self:is_sprint_official() and "Locked Off" or "None")), height * 0.77, width, { 0.82, 0.84, 0.88, 1.0 })
	draw_centered(lg, "Toggle mutators [Z/X/C] base  [B] Blacklight  [I] Ironman", height * 0.82, width, { 0.5, 0.52, 0.58, 1.0 })
	draw_centered(lg, "Up/Down select  Left/Right adjust  Enter confirm or browse target  N seed action", height * 0.87, width, { 0.5, 0.52, 0.58, 1.0 })
	draw_centered(lg, "Loadouts: " .. table.concat((function()
		local values = {}
		for _, entry in ipairs(loadouts) do values[#values + 1] = entry.id end
		return values
	end)(), ", ") .. "   Flames: " .. table.concat((function()
		local values = {}
		for _, entry in ipairs(flames) do values[#values + 1] = entry.id end
		return values
	end)(), ", "), height * 0.92, width, { 0.42, 0.44, 0.5, 1.0 })
end

function App:draw_progression()
	local lg = love.graphics
	local width, height = lg.getDimensions()
	draw_centered(lg, "PROGRESSION", height * 0.08, width, { 0.92, 0.92, 0.96, 1.0 })
	draw_centered(lg, string.format("Runs %d  Victories %d  Burns %d", self.meta.total_runs, self.meta.total_victories, self.meta.total_burns), height * 0.18, width, { 0.7, 0.8, 1.0, 1.0 })

	local y = height * 0.28
	for _, unlock in ipairs(self.meta:get_all_unlocks()) do
		local color = unlock.unlocked and { 0.42, 1.0, 0.42, 1.0 } or { 0.55, 0.55, 0.58, 1.0 }
		draw_centered(lg, string.format("%s  %s  %s", unlock.unlocked and "+" or "-", unlock.label, unlock.desc), y, width, color)
		y = y + 24
	end

	y = y + 14
	draw_centered(lg, "Selected Loadout: " .. (self.settings.selected_loadout or "default"), y, width, { 0.82, 0.84, 0.88, 1.0 })
	draw_centered(lg, "Selected Flame: " .. (self.settings.selected_flame_color or "amber"), y + 26, width, { 0.82, 0.84, 0.88, 1.0 })
	draw_centered(lg, "Esc or Enter returns", height * 0.9, width, { 0.5, 0.52, 0.58, 1.0 })
end

function App:draw_replays()
	local lg = love.graphics
	local width, height = lg.getDimensions()
	draw_centered(lg, "REPLAYS", height * 0.08, width, { 0.92, 0.92, 0.96, 1.0 })
	draw_centered(lg, string.format("Sort %s  Filter %s  PB only %s", self.replay_sort, self.replay_filter_mode, self.replay_pb_only and "ON" or "OFF"), height * 0.15, width, { 0.7, 0.8, 1.0, 1.0 })
	if #self.replay_entries == 0 then
		draw_centered(lg, "No saved replays match the current filter", height * 0.42, width, { 0.72, 0.72, 0.76, 1.0 })
	else
		local y = height * 0.22
		for index, entry in ipairs(self.replay_entries) do
			local replay = entry.replay
			local color = index == self.selected_replay_index and { 1.0, 0.93, 0.35, 1.0 } or { 0.8, 0.82, 0.86, 1.0 }
			local pb_tag = replay.metadata.pb and " PB" or ""
			local line = string.format("%s  %s  %s  %s  %.1fs%s", entry.file, replay.difficulty or "stalker", entry.mode:gsub("_", " "), tostring(replay.seed), replay.metadata.duration or 0, pb_tag)
			if index == self.selected_replay_index then
				line = "> " .. line .. " <"
			end
			draw_centered(lg, line, y, width, color)
			y = y + 24
			if y > height * 0.8 then
				break
			end
		end
	end
	draw_centered(lg, "Up/Down select  Left/Right sort  [F] filter  [P] PB-only  Enter plays  Esc returns", height * 0.9, width, { 0.5, 0.52, 0.58, 1.0 })
end

function App:draw_drills()
	local lg = love.graphics
	local width, height = lg.getDimensions()
	draw_centered(lg, "PRACTICE TARGETS", height * 0.08, width, { 0.92, 0.92, 0.96, 1.0 })
	if #self.drill_entries == 0 then
		draw_centered(lg, "No practice targets available for this seed", height * 0.42, width, { 0.72, 0.72, 0.76, 1.0 })
	else
		local y = height * 0.22
		for index, entry in ipairs(self.drill_entries) do
			local color = index == self.selected_drill_index and { 1.0, 0.93, 0.35, 1.0 } or { 0.8, 0.82, 0.86, 1.0 }
			local record = self.settings.sprint_practice_records[entry.id]
			local suffix = record and ("  Best " .. format_time(record.best_time)) or ""
			local line = string.format("%s  Floor %d%s", entry.label, entry.floor or 1, suffix)
			if index == self.selected_drill_index then
				line = "> " .. line .. " <"
			end
			draw_centered(lg, line, y, width, color)
			y = y + 24
			if y > height * 0.8 then
				break
			end
		end
	end
	draw_centered(lg, "Up/Down select  Enter starts  Esc returns", height * 0.9, width, { 0.5, 0.52, 0.58, 1.0 })
end

function App:draw_result()
	local lg = love.graphics
	local width, height = lg.getDimensions()
	local label = self.last_result == "victory" and "THE DARKNESS BREAKS" or "YOU WERE CAUGHT"
	local color = self.last_result == "victory" and { 0.8, 0.95, 0.4, 1.0 } or { 1.0, 0.4, 0.35, 1.0 }
	draw_centered(lg, label, height * 0.14, width, color)
	if self.last_summary then
		local stats = self.last_summary.stats
		draw_centered(lg, string.format("Mode %s  Seed %d  Time %s", self.last_summary.mode_label or self.last_summary.mode or "classic", self.last_summary.seed, format_time(self.last_summary.duration or 0)), height * 0.24, width, { 0.88, 0.88, 0.92, 1.0 })
		draw_centered(lg, string.format("Floors %d  Damage %d  Torches %d  Sanity %d", stats.floors_cleared, stats.damage_taken, stats.torches_collected, math.floor(self.last_summary.sanity_left or 0)), height * 0.31, width, { 0.82, 0.84, 0.88, 1.0 })
		draw_centered(lg, string.format("Flares %d  Consumables %d  Dashes %d  Boosts %d", stats.flares_used, stats.consumables_used or 0, stats.burn_dashes or 0, stats.flare_boosts or 0), height * 0.37, width, { 0.82, 0.84, 0.88, 1.0 })
		if self.last_summary.mode == "sprint" then
			local split_rows = {}
			local projected_saves = self.last_summary.projected_saves or {}
			if self.last_summary.sprint_ruleset == "official" then
				local medal = self.last_summary.medal or "none"
				local pb_text = self.last_sprint_record and self.last_sprint_record.new_pb and "NEW PB" or "PB unchanged"
				local split_text = self.last_sprint_record and self.last_sprint_record.new_best_splits and "new split bests" or "split table stable"
				local record = self.last_sprint_record and self.last_sprint_record.record or (self.last_summary.category_key and self.settings.sprint_records[self.last_summary.category_key]) or nil
				local best_possible = self.last_sprint_record and self.last_sprint_record.best_possible_time or self.last_summary.best_possible_time
				projected_saves = self.last_sprint_record and self.last_sprint_record.projected_saves or projected_saves
				split_rows = Sprint.get_split_rows(record and record.best_splits or {}, self.last_summary.splits or {})
				draw_centered(lg, string.format("Medal %s  %s  %s  Best Possible %s", medal, pb_text, split_text, best_possible and format_time(best_possible) or "--"), height * 0.44, width, { 0.94, 0.88, 0.42, 1.0 })
			else
				local best = self.last_summary.practice_target and self.settings.sprint_practice_records[self.last_summary.practice_target]
				split_rows = Sprint.get_split_rows({}, self.last_summary.splits or {})
				draw_centered(lg, string.format("Sprint practice: %s  Best %s", self.last_summary.practice_target_label or self.last_summary.practice_target or "target", best and format_time(best.best_time) or "none"), height * 0.44, width, { 0.7, 0.8, 1.0, 1.0 })
			end
			local y = height * 0.50
			for _, split in ipairs(split_rows) do
				local delta = split.delta and ("  " .. format_delta(split.delta)) or ""
				local segment = split.best_segment_time and string.format("  Seg %s / %s", format_time(split.segment_time or 0), format_time(split.best_segment_time or 0))
					or string.format("  Seg %s", format_time(split.segment_time or 0))
				local color = split.gold and { 0.98, 0.88, 0.42, 1.0 } or { 0.78, 0.8, 0.86, 1.0 }
				draw_centered(lg, string.format("%s  %s%s%s", split.label, format_time(split.time or 0), delta, segment), y, width, color)
				y = y + 20
			end
			if self.last_summary.sprint_ruleset == "official" then
				local save_y = y + 10
				draw_centered(lg, "Projected Saves", save_y, width, { 0.72, 0.9, 1.0, 1.0 })
				if #projected_saves == 0 then
					draw_centered(lg, "No segment time left on the table.", save_y + 20, width, { 0.64, 0.68, 0.76, 1.0 })
				else
					for index, save in ipairs(projected_saves) do
						draw_centered(lg, string.format("%s  Save %s", save.label or save.id or "Segment", format_delta(save.save or 0)), save_y + index * 20, width, { 0.72, 0.9, 1.0, 1.0 })
					end
				end
			end
		else
			draw_centered(lg, string.format("Encounters %d  Anchors %d  Wards %d  Pillars %d", stats.encounters_triggered, stats.anchors_lit, stats.wards_triggered or 0, stats.pillars_destroyed or 0), height * 0.44, width, { 0.82, 0.84, 0.88, 1.0 })
		end
	end
	local footer = "[R] Retry  [N] Seed Action  [S] Save Replay  [P] Progression  [V] Replays  [Enter] Title"
	if self.last_summary and self.last_summary.mode == "sprint" then
		footer = footer .. "  [1/2/3] Practice Floors  [D] Targets  [G] PB Replay"
	end
	draw_centered(lg, footer, height * 0.86, width, { 0.55, 0.58, 0.64, 1.0 })
end

function App:draw()
	local lg = love.graphics
	lg.clear(0.02, 0.02, 0.03)

	if self.screen == "title" then
		self:draw_title()
	elseif self.screen == "play" then
		self.run:draw()
	elseif self.screen == "progression" then
		self:draw_progression()
	elseif self.screen == "replays" then
		self:draw_replays()
	elseif self.screen == "drills" then
		self:draw_drills()
	else
		self:draw_result()
	end
end

function App:adjust_title_item(direction)
	local item = title_items[self.title_index]
	if item == "difficulty" and self.selected_mode ~= "daily" then
		self.selected_difficulty = cycle_value(difficulty_cycle, self.selected_difficulty, direction)
	elseif item == "mode" then
		self.selected_mode = cycle_value(mode_cycle, self.selected_mode, direction)
	elseif item == "sprint_pack" and self.selected_mode == "sprint" then
		local packs = Sprint.list_packs()
		local ids = {}
		for _, pack in ipairs(packs) do ids[#ids + 1] = pack.id end
		self.settings.selected_sprint_pack_id = cycle_value(ids, self.settings.selected_sprint_pack_id or Sprint.get_default_pack_id(), direction)
		self.settings.selected_sprint_seed_id = Sprint.get_seed_by_index(self.settings.selected_sprint_pack_id, 1).id
		self.settings.selected_sprint_practice_target = Sprint.normalize_practice_target(self.settings.selected_sprint_pack_id, self.settings.selected_sprint_seed_id, self.settings.selected_sprint_practice_target or "floor:1")
	elseif item == "sprint_ruleset" and self.selected_mode == "sprint" then
		self.settings.selected_sprint_ruleset = cycle_value(sprint_ruleset_cycle, self.settings.selected_sprint_ruleset or "official", direction)
		if self.settings.selected_sprint_ruleset == "official" and self.settings.selected_sprint_seed_id == "random" then
			self.settings.selected_sprint_seed_id = Sprint.get_seed_by_index(self.settings.selected_sprint_pack_id or Sprint.get_default_pack_id(), 1).id
		end
		self.settings.selected_sprint_practice_target = Sprint.normalize_practice_target(
			self.settings.selected_sprint_pack_id or Sprint.get_default_pack_id(),
			self.settings.selected_sprint_seed_id,
			self.settings.selected_sprint_practice_target or "floor:1"
		)
	elseif item == "sprint_seed" and self.selected_mode == "sprint" then
		self:advance_sprint_seed(direction)
		return
	elseif item == "practice_target" and self.selected_mode == "sprint" and self.settings.selected_sprint_ruleset == "practice" then
		self.settings.selected_sprint_practice_target = Sprint.next_practice_target(
			self.settings.selected_sprint_pack_id or Sprint.get_default_pack_id(),
			self.settings.selected_sprint_seed_id,
			self:get_practice_target_id(),
			direction
		)
	elseif item == "loadout" and self.selected_mode ~= "daily" and not self:is_sprint_official() then
		local values = {}
		for _, entry in ipairs(self:get_available_loadouts()) do values[#values + 1] = entry.id end
		self.settings.selected_loadout = cycle_value(values, self.settings.selected_loadout or "default", direction)
	elseif item == "flame" and self.selected_mode ~= "daily" then
		local values = {}
		for _, entry in ipairs(self:get_available_flames()) do values[#values + 1] = entry.id end
		self.settings.selected_flame_color = cycle_value(values, self.settings.selected_flame_color or "amber", direction)
	end
	self:save_settings()
end

function App:toggle_mutator(key)
	if self.selected_mode == "daily" or self:is_sprint_official() then
		return
	end
	if key == "z" then
		self.selected_mutators.embers = not self.selected_mutators.embers
	elseif key == "x" then
		self.selected_mutators.echoes = not self.selected_mutators.echoes
	elseif key == "c" then
		self.selected_mutators.onslaught = not self.selected_mutators.onslaught
	elseif key == "b" and self.meta:is_unlocked("mutator_blacklight") then
		self.selected_mutators.blacklight = not self.selected_mutators.blacklight
	elseif key == "i" and self.meta:is_unlocked("mutator_ironman") then
		self.selected_mutators.ironman = not self.selected_mutators.ironman
	end
end

function App:handle_new_seed_action()
	if self.selected_mode == "sprint" then
		if self.settings.selected_sprint_ruleset == "official" then
			self:advance_sprint_seed(1)
		elseif self.settings.selected_sprint_seed_id == "random" then
			self.seed = os.time() + love.math.random(1, 99999)
		else
			self:advance_sprint_seed(1)
		end
	else
		self.seed = os.time() + love.math.random(1, 99999)
	end
end

function App:keypressed(key)
	if self.screen == "title" then
		if key == "up" then
			self.title_index = math.max(1, self.title_index - 1)
		elseif key == "down" then
			self.title_index = math.min(#title_items, self.title_index + 1)
		elseif key == "left" then
			self:adjust_title_item(-1)
		elseif key == "right" then
			self:adjust_title_item(1)
		elseif key == "n" then
			self:handle_new_seed_action()
		elseif key == "z" or key == "x" or key == "c" or key == "b" or key == "i" then
			self:toggle_mutator(key)
		elseif key == "return" then
			local item = title_items[self.title_index]
			if item == "start" then
				self:start_run()
			elseif item == "practice_target" and self.selected_mode == "sprint" and self.settings.selected_sprint_ruleset == "practice" then
				self:open_drill_browser(self:get_effective_config())
			elseif item == "progression" then
				self.screen = "progression"
			elseif item == "replays" then
				self:refresh_replays()
				self.screen = "replays"
			elseif item == "quit" then
				love.event.quit()
			end
		elseif key == "escape" then
			love.event.quit()
		end
		return
	end

	if self.screen == "progression" then
		if key == "escape" or key == "return" then
			self.screen = "title"
		end
		return
	end

	if self.screen == "replays" then
		if key == "up" then
			self.selected_replay_index = math.max(1, self.selected_replay_index - 1)
		elseif key == "down" then
			self.selected_replay_index = math.min(#self.replay_entries, self.selected_replay_index + 1)
		elseif key == "left" then
			self.replay_sort = cycle_value(replay_sort_cycle, self.replay_sort, -1)
			self:refresh_replays()
		elseif key == "right" then
			self.replay_sort = cycle_value(replay_sort_cycle, self.replay_sort, 1)
			self:refresh_replays()
		elseif key == "f" then
			self.replay_filter_mode = cycle_value(replay_filter_cycle, self.replay_filter_mode, 1)
			self:refresh_replays()
		elseif key == "p" then
			self.replay_pb_only = not self.replay_pb_only
			self:refresh_replays()
		elseif key == "return" then
			if self:start_selected_replay() then
				self.screen = "play"
			end
		elseif key == "escape" then
			self.screen = "title"
		end
		return
	end

	if self.screen == "drills" then
		if key == "up" then
			self.selected_drill_index = math.max(1, self.selected_drill_index - 1)
		elseif key == "down" then
			self.selected_drill_index = math.min(#self.drill_entries, self.selected_drill_index + 1)
		elseif key == "return" then
			if self:start_selected_drill_target() then
				self.screen = "play"
			end
		elseif key == "escape" then
			self.screen = self.last_result or "title"
		end
		return
	end

	if self.screen == "play" and self.run then
		if self.run.replay_mode then
			if key == "escape" then
				self:return_to_title()
			end
			return
		end
		if Replay.is_recording() then
			Replay.record_key_state(key, true, self.run.clock)
		end
		if self.run.paused and (key == "v" or key == "s") then
			self:save_replay_snapshot("pause_save")
			return
		end
		self.run:keypressed(key)
		return
	end

	if key == "return" then
		self.screen = "title"
	elseif key == "r" and self.last_run_config then
		self:start_run(self.last_run_config)
	elseif key == "n" then
		if self.last_run_config and self.last_run_config.mode == "sprint" then
			if self.last_run_config.sprint_ruleset == "official" then
				self.settings.selected_sprint_seed_id = Sprint.next_seed_id(self.last_run_config.sprint_seed_pack_id, self.last_run_config.sprint_seed_id, 1, false)
				self:save_settings()
				self:start_run(self:get_effective_config())
			elseif self.last_run_config.sprint_seed_id then
				self.settings.selected_sprint_seed_id = Sprint.next_seed_id(self.last_run_config.sprint_seed_pack_id or Sprint.get_default_pack_id(), self.last_run_config.sprint_seed_id, 1, true)
				self:save_settings()
				self:start_run(self:get_effective_config())
			else
				self.seed = os.time() + love.math.random(1, 99999)
				local config = util.deepcopy(self.last_run_config)
				config.seed = self.seed
				self:start_run(config)
			end
		else
			self.seed = os.time() + love.math.random(1, 99999)
			local config = util.deepcopy(self.last_run_config or self:get_effective_config())
			config.seed = self.seed
			self:start_run(config)
		end
	elseif key == "s" and self.last_summary and self.last_summary.outcome and not (self.run and self.run.replay_mode) then
		self:save_replay_snapshot("result_save")
	elseif key == "p" then
		self.screen = "progression"
	elseif key == "v" then
		self:refresh_replays()
		self.screen = "replays"
	elseif key == "d" and self.last_summary and self.last_summary.mode == "sprint" then
		self:open_drill_browser(self.last_run_config)
	elseif (key == "1" or key == "2" or key == "3") and self.last_summary and self.last_summary.mode == "sprint" then
		self:start_practice_floor(tonumber(key))
	elseif key == "g" and self.last_summary and self.last_summary.mode == "sprint" then
		if self:start_pb_replay() then
			self.screen = "play"
		end
	end
end

function App:keyreleased(key)
	if self.screen == "play" and self.run then
		if not self.run.replay_mode and Replay.is_recording() then
			Replay.record_key_state(key, false, self.run.clock)
		end
		self.run:keyreleased(key)
	end
end

function App:resize(_width, _height)
end

return App
