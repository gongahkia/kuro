local Run = require("src.game.run")
local Settings = require("src.core.settings")
local LoreData = require("src.data.lore")
local Difficulty = require("src.data.difficulty")
local Meta = require("src.game.meta")

local App = {}
App.__index = App

function App.new()
	return setmetatable({
		screen = "title",
		selected_difficulty = "stalker",
		seed = os.time(),
		run = nil,
		last_result = nil,
		last_summary = nil,
		settings = Settings.load(),
		meta = nil, -- init in :load()
		selected_mutators = {
			embers = false,
			echoes = false,
			onslaught = false,
		},
	}, App)
end

function App:load(_args)
	self.meta = Meta.new(self.settings)
end

function App:start_run(seed_override)
	self.seed = seed_override or self.seed
	self.run = Run.new(self.selected_difficulty, self.seed, self.selected_mutators, self.settings)
	self.screen = "play"
end

function App:update(dt)
	if self.screen == "play" and self.run then
		local outcome = self.run:update(dt)
		if outcome == "dead" then
			self.last_summary = self.run:summary()
			self.screen = "dead"
			self.last_result = "dead"
			if self.meta then
				self.meta:record_run(self.last_summary)
				self.meta:save(self.settings)
				Settings.save(self.settings)
			end
		elseif outcome == "victory" then
			self.last_summary = self.run:summary()
			self.last_summary.difficulty = "victory"
			self.screen = "victory"
			self.last_result = "victory"
			if self.meta then
				self.meta:record_run(self.last_summary)
				self.meta:save(self.settings)
				Settings.save(self.settings)
			end
		end
	end
end

function App:draw()
	local lg = love.graphics
	lg.clear(0.02, 0.02, 0.03)

	if self.screen == "title" then
		self:draw_title()
	elseif self.screen == "play" then
		self.run:draw()
	else
		self:draw_result()
	end
end

function App:draw_title()
	local lg = love.graphics
	local width, height = lg.getDimensions()
	local time = love.timer.getTime()
	local title_alpha = 1.0
	if self.settings.title_flicker then
		title_alpha = math.sin(time * 2.5) * 0.15 + 0.85
	end
	lg.setColor(0.87, 0.89, 0.95, title_alpha)
	lg.printf("KURO", 0, height * 0.15, width, "center")
	lg.setColor(0.45, 0.72, 1.0)
	lg.printf("First-person light survival descent", 0, height * 0.23, width, "center")
	local lore = LoreData.fragments
	local lore_index = math.floor(time / 4) % #lore + 1
	lg.setColor(0.4, 0.42, 0.48, 0.7)
	lg.printf("\"" .. lore[lore_index].text .. "\"", width * 0.15, height * 0.30, width * 0.7, "center")
	lg.setColor(0.82, 0.84, 0.88)
	lg.printf("Difficulty: " .. self.selected_difficulty, 0, height * 0.40, width, "center")
	local preview = Difficulty.build(self.selected_difficulty, 1, self.selected_mutators)
	lg.setColor(0.55, 0.58, 0.64)
	lg.printf(string.format("HP %d  View %.1f  Threat %d  Torches %d", preview.player_health, preview.view_distance, preview.threat_budget, preview.torch_goal), 0, height * 0.44, width, "center")
	lg.setColor(0.82, 0.84, 0.88)
	lg.printf("Seed: " .. tostring(self.seed), 0, height * 0.49, width, "center")
	local mutators = {}
	if self.selected_mutators.embers then
		mutators[#mutators + 1] = "Embers"
	end
	if self.selected_mutators.echoes then
		mutators[#mutators + 1] = "Echoes"
	end
	if self.selected_mutators.onslaught then
		mutators[#mutators + 1] = "Onslaught"
	end
	lg.printf("Mutators: " .. (#mutators > 0 and table.concat(mutators, ", ") or "None"), 0, height * 0.55, width, "center")
	lg.printf("[1/2/3] Difficulty  [N] New seed  [Z/X/C] Mutators  [Enter] Start", 0, height * 0.64, width, "center")
	lg.printf("W/S move  A/D turn  Q/E strafe  F light  Shift burst  G flare  Space interact  Esc pause", 0, height * 0.70, width, "center")
end

function App:draw_result()
	local lg = love.graphics
	local width, height = lg.getDimensions()
	local label = self.last_result == "victory" and "THE DARKNESS BREAKS" or "YOU WERE CAUGHT"
	local color = self.last_result == "victory" and {0.8, 0.95, 0.4} or {1.0, 0.4, 0.35}
	lg.setColor(color)
	lg.printf(label, 0, height * 0.28, width, "center")
	lg.setColor(0.88, 0.88, 0.92)
	lg.printf("Seed: " .. tostring(self.seed), 0, height * 0.40, width, "center")
	if self.last_summary then
		local stats = self.last_summary.stats
		lg.printf(string.format("Floors cleared: %d   Damage taken: %d   Torches: %d", stats.floors_cleared, stats.damage_taken, stats.torches_collected), 0, height * 0.48, width, "center")
		lg.printf(string.format("Encounters: %d   Anchors lit: %d   Flares used: %d", stats.encounters_triggered, stats.anchors_lit, stats.flares_used), 0, height * 0.54, width, "center")
	end
	lg.printf("[R] Retry seed  [N] New seed  [Enter] Title", 0, height * 0.64, width, "center")
end

function App:keypressed(key)
	if key == "escape" and self.screen ~= "play" then
		love.event.quit()
		return
	end
	if self.screen == "title" then
		if key == "1" then
			self.selected_difficulty = "apprentice"
		elseif key == "2" then
			self.selected_difficulty = "stalker"
		elseif key == "3" then
			self.selected_difficulty = "nightmare"
		elseif key == "n" then
			self.seed = os.time() + love.math.random(1, 99999)
		elseif key == "z" then
			self.selected_mutators.embers = not self.selected_mutators.embers
		elseif key == "x" then
			self.selected_mutators.echoes = not self.selected_mutators.echoes
		elseif key == "c" then
			self.selected_mutators.onslaught = not self.selected_mutators.onslaught
		elseif key == "return" then
			self:start_run(self.seed)
		end
		return
	end

	if self.screen == "play" and self.run then
		self.run:keypressed(key)
		return
	end

	if key == "return" then
		self.screen = "title"
	elseif key == "r" then
		self:start_run(self.seed)
	elseif key == "n" then
		self.seed = os.time() + love.math.random(1, 99999)
		self:start_run(self.seed)
	end
end

function App:keyreleased(key)
	if self.screen == "play" and self.run then
		self.run:keyreleased(key)
	end
end

function App:resize(_width, _height)
end

return App
