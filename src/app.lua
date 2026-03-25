local Run = require("src.game.run")
local Settings = require("src.core.settings")
local LoreData = require("src.data.lore")
local Difficulty = require("src.data.difficulty")
local Meta = require("src.game.meta")
local Replay = require("src.game.replay")
local Challenges = require("src.game.challenges")
local util = require("src.core.util")

local App = {}
App.__index = App

local title_items = {
	"start",
	"difficulty",
	"mode",
	"loadout",
	"flame",
	"progression",
	"replays",
	"quit",
}

local difficulty_cycle = { "apprentice", "stalker", "nightmare" }
local mode_cycle = { "classic", "daily", "time_attack" }

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
		settings = Settings.load(),
		meta = nil,
		replay_entries = {},
		selected_replay_index = 1,
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
	self.seed = os.time()
	Replay.init()
	self:refresh_replays()
end

function App:save_settings()
	self.settings.selected_mode = self.selected_mode
	self.meta:save(self.settings)
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
		}
	end

	return {
		mode = self.selected_mode,
		difficulty = self.selected_difficulty,
		seed = self.seed,
		mutators = self.selected_mutators,
		loadout = self.settings.selected_loadout or "default",
		flame_color = self.settings.selected_flame_color or "amber",
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

function App:start_run(config)
	config = config or self:get_effective_config()
	self.seed = config.seed
		self.last_run_config = {
			mode = config.mode,
			difficulty = config.difficulty,
			seed = config.seed,
			mutators = util.deepcopy(config.mutators or {}),
		loadout = config.loadout,
		flame_color = config.flame_color,
		daily_label = config.daily_label,
		replay_mode = config.replay_mode,
	}
	self.run = Run.new(config.difficulty, config.seed, config.mutators, self.settings, {
		mode = config.mode,
		daily_label = config.daily_label,
		loadout = config.loadout,
		flame_color = config.flame_color,
		replay_mode = config.replay_mode == true,
	})
	if not config.replay_mode then
		Replay.start_recording(config.seed, config.difficulty, {
			mode = config.mode,
			daily_label = config.daily_label,
			mutators = config.mutators,
			loadout = config.loadout,
			flame_color = config.flame_color,
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

function App:refresh_replays()
	local entries = {}
	for _, file in ipairs(Replay.list_replays()) do
		local replay = Replay.inspect(file)
		if replay then
			entries[#entries + 1] = {
				file = file,
				replay = replay,
			}
		end
	end
	self.replay_entries = entries
	if self.selected_replay_index > #entries then
		self.selected_replay_index = #entries
	end
	if self.selected_replay_index < 1 then
		self.selected_replay_index = 1
	end
end

function App:save_replay_snapshot()
	if not self.run or self.run.replay_mode or not Replay.has_data() then
		return false
	end
	local ok = Replay.save()
	if ok then
		self:refresh_replays()
		if self.run then
			self.run:push_message("Replay saved.")
			self.run.replay_save_requested = false
		end
	end
	return ok
end

function App:record_result(outcome)
	self.last_summary = self.run:summary()
	self.last_summary.difficulty = outcome == "victory" and "victory" or self.last_summary.difficulty
	self.last_summary.outcome = outcome
	self.last_result = outcome
	self.screen = outcome
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
		end
	end

	self:save_settings()
	Replay.stop_recording()
	Replay.stop_playback()
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
		difficulty = replay.difficulty or "stalker",
		seed = replay.seed,
		mutators = context.mutators or {},
		loadout = context.loadout or "default",
		flame_color = context.flame_color or "amber",
		replay_mode = true,
	})
	return Replay.start_playback()
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
	if self.run.replay_save_requested then
		self:save_replay_snapshot()
	end
	if outcome == "dead" then
		self:record_result("dead")
	elseif outcome == "victory" then
		self:record_result("victory")
	end
end

function App:draw_title()
	local lg = love.graphics
	local width, height = lg.getDimensions()
	local time = love.timer.getTime()
	local config = self:get_effective_config()
	local preview = self:get_preview()
	local title_alpha = self.settings.title_flicker and (math.sin(time * 2.5) * 0.15 + 0.85) or 1.0
	local lore = LoreData.fragments
	local lore_index = math.floor(time / 4) % #lore + 1
	local loadouts = self:get_available_loadouts()
	local flames = self:get_available_flames()
	local mutators = {}
	for name, enabled in pairs(config.mutators) do
		if enabled then
			mutators[#mutators + 1] = name
		end
	end
	table.sort(mutators)

	draw_centered(lg, "KURO", height * 0.10, width, { 0.87, 0.89, 0.95, title_alpha })
	draw_centered(lg, "First-person light survival descent", height * 0.18, width, { 0.45, 0.72, 1.0, 1.0 })
	draw_centered(lg, "\"" .. lore[lore_index].text .. "\"", height * 0.25, width, { 0.4, 0.42, 0.48, 0.7 })

	local items = {
		{ key = "start", label = "Start Run" },
		{ key = "difficulty", label = "Difficulty", value = config.difficulty },
		{ key = "mode", label = "Mode", value = config.mode },
		{ key = "loadout", label = "Loadout", value = config.loadout },
		{ key = "flame", label = "Flame", value = config.flame_color },
		{ key = "progression", label = "Progression" },
		{ key = "replays", label = "Replays", value = tostring(#self.replay_entries) },
		{ key = "quit", label = "Quit" },
	}

	local start_y = height * 0.36
	for index, item in ipairs(items) do
		local text = item.value and string.format("%s: %s", item.label, item.value) or item.label
		local color = index == self.title_index and { 1.0, 0.93, 0.35, 1.0 } or { 0.82, 0.84, 0.88, 1.0 }
		if index == self.title_index then
			text = "> " .. text .. " <"
		end
		draw_centered(lg, text, start_y + (index - 1) * 28, width, color)
	end

	draw_centered(lg, string.format("HP %d  View %.1f  Threat %d  Torches %d  Flares %d", preview.hp, preview.view_distance, preview.threat_budget, preview.torch_goal, preview.flares), height * 0.67, width, { 0.55, 0.58, 0.64, 1.0 })
	if config.mode == "daily" and config.daily_label then
		local best = self.settings.daily_records[config.daily_label]
		draw_centered(lg, string.format("Daily Seed %d  Best %s", config.seed, best and string.format("%.1fs", best) or "none"), height * 0.72, width, { 0.66, 0.82, 0.96, 1.0 })
	elseif config.mode == "time_attack" then
		local best = self.settings.time_attack_records[config.difficulty]
		draw_centered(lg, string.format("Seed %d  Best %s", config.seed, best and string.format("%.1fs", best) or "none"), height * 0.72, width, { 0.95, 0.8, 0.28, 1.0 })
	else
		draw_centered(lg, "Seed: " .. tostring(config.seed), height * 0.72, width, { 0.82, 0.84, 0.88, 1.0 })
	end
	draw_centered(lg, "Mutators: " .. (#mutators > 0 and table.concat(mutators, ", ") or "None"), height * 0.77, width, { 0.82, 0.84, 0.88, 1.0 })
	draw_centered(lg, "Toggle mutators [Z/X/C] base  [B] Blacklight  [I] Ironman", height * 0.84, width, { 0.5, 0.52, 0.58, 1.0 })
	draw_centered(lg, "Up/Down select  Left/Right adjust  Enter confirm  N new seed", height * 0.89, width, { 0.5, 0.52, 0.58, 1.0 })
	draw_centered(lg, "Loadouts: " .. table.concat((function()
		local values = {}
		for _, entry in ipairs(loadouts) do values[#values + 1] = entry.id end
		return values
	end)(), ", ") .. "   Flames: " .. table.concat((function()
		local values = {}
		for _, entry in ipairs(flames) do values[#values + 1] = entry.id end
		return values
	end)(), ", "), height * 0.93, width, { 0.42, 0.44, 0.5, 1.0 })
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
	if #self.replay_entries == 0 then
		draw_centered(lg, "No saved replays yet", height * 0.42, width, { 0.72, 0.72, 0.76, 1.0 })
	else
		local y = height * 0.2
		for index, entry in ipairs(self.replay_entries) do
			local replay = entry.replay
			local color = index == self.selected_replay_index and { 1.0, 0.93, 0.35, 1.0 } or { 0.8, 0.82, 0.86, 1.0 }
			local line = string.format("%s  %s  %s  %.1fs", entry.file, replay.difficulty or "stalker", replay.context.mode or "classic", replay.metadata.duration or 0)
			if index == self.selected_replay_index then
				line = "> " .. line .. " <"
			end
			draw_centered(lg, line, y, width, color)
			y = y + 28
		end
	end
	draw_centered(lg, "Up/Down select  Enter plays  Esc returns", height * 0.9, width, { 0.5, 0.52, 0.58, 1.0 })
end

function App:draw_result()
	local lg = love.graphics
	local width, height = lg.getDimensions()
	local label = self.last_result == "victory" and "THE DARKNESS BREAKS" or "YOU WERE CAUGHT"
	local color = self.last_result == "victory" and { 0.8, 0.95, 0.4 } or { 1.0, 0.4, 0.35 }
	draw_centered(lg, label, height * 0.20, width, color)
	if self.last_summary then
		local stats = self.last_summary.stats
		draw_centered(lg, string.format("Mode %s  Seed %d  Time %.1fs", self.last_summary.mode_label or self.last_summary.mode or "classic", self.last_summary.seed, self.last_summary.duration or 0), height * 0.34, width, { 0.88, 0.88, 0.92, 1.0 })
		draw_centered(lg, string.format("Floors %d  Damage %d  Torches %d  Sanity %d", stats.floors_cleared, stats.damage_taken, stats.torches_collected, math.floor(self.last_summary.sanity_left or 0)), height * 0.42, width, { 0.82, 0.84, 0.88, 1.0 })
		draw_centered(lg, string.format("Encounters %d  Anchors %d  Flares %d  Consumables %d", stats.encounters_triggered, stats.anchors_lit, stats.flares_used, stats.consumables_used or 0), height * 0.48, width, { 0.82, 0.84, 0.88, 1.0 })
		draw_centered(lg, string.format("Wards %d  Secrets %d  Pillars %d", stats.wards_triggered or 0, stats.secrets_revealed or 0, stats.pillars_destroyed or 0), height * 0.54, width, { 0.82, 0.84, 0.88, 1.0 })
	end
	draw_centered(lg, "[R] Retry  [N] New Seed  [S] Save Replay  [P] Progression  [V] Replays  [Enter] Title", height * 0.68, width, { 0.55, 0.58, 0.64, 1.0 })
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
	elseif item == "loadout" and self.selected_mode ~= "daily" then
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
	if self.selected_mode == "daily" then
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
		elseif key == "n" and self.selected_mode ~= "daily" then
			self.seed = os.time() + love.math.random(1, 99999)
		elseif key == "z" or key == "x" or key == "c" or key == "b" or key == "i" then
			self:toggle_mutator(key)
		elseif key == "return" then
			local item = title_items[self.title_index]
			if item == "start" then
				self:start_run()
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
		elseif key == "return" then
			if self:start_selected_replay() then
				self.screen = "play"
			end
		elseif key == "escape" then
			self.screen = "title"
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
			self:save_replay_snapshot()
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
		self.seed = os.time() + love.math.random(1, 99999)
		local config = self.last_run_config or self:get_effective_config()
		config.seed = self.seed
		self:start_run(config)
	elseif key == "s" and self.last_summary and self.last_summary.outcome and not self.run.replay_mode then
		self:save_replay_snapshot()
	elseif key == "p" then
		self.screen = "progression"
	elseif key == "v" then
		self:refresh_replays()
		self.screen = "replays"
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
