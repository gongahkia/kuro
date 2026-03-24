local AI = require("src.game.ai")
local Generator = require("src.world.generator")

return {
	["visible enemy enters chase state"] = function()
		local world = Generator.generate("apprentice", 3, 1, nil)
		local enemy = world.enemies[1]
		enemy.x = enemy.home_x
		enemy.y = enemy.home_y
		local state = AI.describe(enemy, {
			world = world,
			player = { x = enemy.x + 0.8, y = enemy.y, angle = 0 },
			alarm_time = 0,
		})
		assert(state == "chase", "expected chase state")
	end,

	["leech retreat overrides chase"] = function()
		local state = AI.describe({
			kind = "leech",
			x = 1.0,
			y = 1.0,
			retreat_time = 1.0,
		}, {
			world = Generator.generate("apprentice", 5, 1, nil),
			player = { x = 1.2, y = 1.0, angle = 0 },
			alarm_time = 0,
		})
		assert(state == "retreat", "expected retreat state")
	end,
}
