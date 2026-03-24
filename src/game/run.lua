local Run = {}
Run.__index = Run

function Run.new(difficulty, seed)
	return setmetatable({
		difficulty = difficulty,
		seed = seed,
		elapsed = 0,
	}, Run)
end

function Run:update(dt)
	self.elapsed = self.elapsed + dt
	return nil
end

function Run:draw()
	local lg = love.graphics
	local width, height = lg.getDimensions()
	lg.setColor(0.12, 0.12, 0.16)
	lg.rectangle("fill", 0, 0, width, height)
	lg.setColor(0.92, 0.92, 0.95)
	lg.printf("Renderer and game systems are being initialized.", 0, height * 0.44, width, "center")
	lg.printf("Difficulty: " .. tostring(self.difficulty) .. "   Seed: " .. tostring(self.seed), 0, height * 0.50, width, "center")
end

function Run:keypressed(_key)
end

function Run:keyreleased(_key)
end

return Run
