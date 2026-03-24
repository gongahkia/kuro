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

	["collecting goal and using exit ends the slice"] = function()
		local run = Run.new("apprentice", 12)
		run.player.collected_torches = run.player.torch_goal
		run.player.x = run.world.exit.x
		run.player.y = run.world.exit.y
		run:interact()
		assert(run:update(0) == "victory", "expected slice victory")
	end,
}
