local Generator = require("src.world.generator")
local World = require("src.world.world")

return {
	["generator is deterministic for the same seed"] = function()
		local left = Generator.generate("stalker", 99, 1, nil)
		local right = Generator.generate("stalker", 99, 1, nil)
		assert(World.snapshot(left) == World.snapshot(right), "expected identical snapshots")
	end,

	["generator produces reachable torches and exit"] = function()
		local world = Generator.generate("apprentice", 7, 1, nil)
		local reachable = World.reachable_cells(world, world.spawn.cell)
		for _, pickup in ipairs(world.pickups) do
			if pickup.kind == "torch" then
				local key = pickup.cell.x .. ":" .. pickup.cell.y
				assert(reachable[key], "torch should be reachable")
			end
		end
		local exit_key = world.exit.cell.x .. ":" .. world.exit.cell.y
		assert(reachable[exit_key], "exit should be reachable")
	end,

	["boss floor exposes reachable anchors"] = function()
		local world = Generator.generate("nightmare", 31, 3, nil)
		local reachable = World.reachable_cells(world, world.spawn.cell)
		assert(world.exit == nil, "boss floor should not create a regular exit")
		assert(world.bossRoom ~= nil, "boss room metadata should exist")
		assert(#world.pillars == 4, "expected preserved boss pillars")
		assert(#world.sanityZones.safe >= 1, "expected safe sanity zone")
		assert(#world.sanityZones.dark >= 1, "expected dark sanity zone")
		assert(#world.anchors == 3, "expected three anchors")
		for _, anchor in ipairs(world.anchors) do
			local key = anchor.cell.x .. ":" .. anchor.cell.y
			assert(reachable[key], "anchor should be reachable")
		end
	end,

	["standard floor preserves sanity zones and consumables"] = function()
		local world = Generator.generate("stalker", 14, 1, nil)
		assert(#world.sanityZones.safe >= 1, "expected at least one safe zone")
		assert(#world.sanityZones.dark >= 1, "expected at least one dark zone")
		assert(world.decorations ~= nil, "expected preserved decorations table")
		local found_consumable = false
		for _, pickup in ipairs(world.pickups) do
			if pickup.kind == "calming_tonic" or pickup.kind == "speed_tonic" or pickup.kind == "ward_charge" then
				found_consumable = true
			end
		end
		assert(found_consumable, "expected at least one consumable pickup")
	end,
}
