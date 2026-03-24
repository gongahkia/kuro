local Run = require("src.game.run")

local App = {}
App.__index = App

function App.new()
	return setmetatable({
		screen = "title",
		selected_difficulty = "stalker",
		seed = os.time(),
		run = nil,
		last_result = nil,
	}, App)
end

function App:load(_args)
end

function App:start_run(seed_override)
	self.seed = seed_override or self.seed
	self.run = Run.new(self.selected_difficulty, self.seed)
	self.screen = "play"
end

function App:update(dt)
	if self.screen == "play" and self.run then
		local outcome = self.run:update(dt)
		if outcome == "dead" then
			self.screen = "dead"
			self.last_result = "dead"
		elseif outcome == "victory" then
			self.screen = "victory"
			self.last_result = "victory"
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
	lg.setColor(0.87, 0.89, 0.95)
	lg.printf("KURO", 0, height * 0.15, width, "center")
	lg.setColor(0.45, 0.72, 1.0)
	lg.printf("First-person light survival prototype", 0, height * 0.23, width, "center")
	lg.setColor(0.82, 0.84, 0.88)
	lg.printf("Difficulty: " .. self.selected_difficulty, 0, height * 0.40, width, "center")
	lg.printf("Seed: " .. tostring(self.seed), 0, height * 0.46, width, "center")
	lg.printf("[1/2/3] Difficulty  [N] New seed  [Enter] Start", 0, height * 0.62, width, "center")
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
	lg.printf("[R] Retry seed  [N] New seed  [Enter] Title", 0, height * 0.60, width, "center")
end

function App:keypressed(key)
	if self.screen == "title" then
		if key == "1" then
			self.selected_difficulty = "apprentice"
		elseif key == "2" then
			self.selected_difficulty = "stalker"
		elseif key == "3" then
			self.selected_difficulty = "nightmare"
		elseif key == "n" then
			self.seed = os.time() + love.math.random(1, 99999)
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
