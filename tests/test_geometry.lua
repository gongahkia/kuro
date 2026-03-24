local World = require("src.world.world")
local Geometry = require("src.world.geometry")

local function tiny_world()
	return World.build({
		width = 3,
		height = 1,
		floor = 1,
		cells = {
			{
				{ walkable = true, floor = 0, ceiling = 1.2, tags = {} },
				{ walkable = true, floor = 0, ceiling = 1.2, tags = {} },
				{ walkable = true, floor = 0, ceiling = 1.2, tags = {} },
			},
		},
		doors = {
			{ a = { x = 1, y = 1 }, b = { x = 2, y = 1 } },
		},
		pickups = {},
		encounterNodes = {},
		enemies = {},
		spawn = { cell = { x = 1, y = 1 }, angle = 0 },
		exit = { cell = { x = 3, y = 1 }, locked = false },
	})
end

return {
	["distance to segment resolves perpendicular projection"] = function()
		local distance = Geometry.distance_to_segment(0.5, 1.0, 0.0, 0.0, 1.0, 0.0)
		assert(math.abs(distance - 1.0) < 0.0001, "expected distance of 1")
	end,

	["closed door blocks line of sight"] = function()
		local world = tiny_world()
		assert(not World.has_line_of_sight(world, 0.5, 0.5, 2.5, 0.5), "closed door should block sight")
		world.doors[1].progress = 1
		assert(World.has_line_of_sight(world, 0.5, 0.5, 2.5, 0.5), "open door should allow sight")
	end,
}
