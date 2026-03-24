local App = require("src.app")

local app

function love.load(args)
	love.math.setRandomSeed(os.time())
	love.keyboard.setKeyRepeat(false)
	app = App.new()
	app:load(args or {})
end

function love.update(dt)
	app:update(dt)
end

function love.draw()
	app:draw()
end

function love.keypressed(key, scancode, isrepeat)
	app:keypressed(key, scancode, isrepeat)
end

function love.keyreleased(key, scancode)
	app:keyreleased(key, scancode)
end

function love.resize(width, height)
	app:resize(width, height)
end
