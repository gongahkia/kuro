local Run = require("src.game.run")

local function find_pickup(run, kind)
	for _, pickup in ipairs(run.world.pickups) do
		if pickup.kind == kind and pickup.active then
			return pickup
		end
	end
	return nil
end

return {
	["interacting on a torch collects it"] = function()
		local run = Run.new("apprentice", 11)
		local torch = find_pickup(run, "torch")
		run.player.x = torch.x
		run.player.y = torch.y
		run:interact()
		assert(run.player.collected_torches == 1, "expected torch count to increase")
		assert(torch.active == false, "torch should deactivate after pickup")
	end,

	["collecting goal and using exit advances a floor"] = function()
		local run = Run.new("apprentice", 12)
		run.player.collected_torches = run.player.torch_goal
		run.player.inventory_torches = run.player.torch_goal
		run.player.x = run.world.exit.x
		run.player.y = run.world.exit.y
		run:interact()
		assert(run.floor == 2, "expected to advance to floor two")
	end,

	["lighting anchors can finish the boss floor"] = function()
		local run = Run.new("stalker", 18)
		run:load_floor(3)
		run.player.inventory_torches = #run.world.anchors
		for _, anchor in ipairs(run.world.anchors) do
			run.player.x = anchor.x
			run.player.y = anchor.y
			run:interact()
		end
		assert(run:update(0) == "victory", "expected boss victory after all anchors are lit")
	end,
}
