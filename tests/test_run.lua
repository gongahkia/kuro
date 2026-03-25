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

	["consumables fill the belt and wards block damage"] = function()
		local run = Run.new("stalker", 22)
		local pickup = run:spawn_pickup("ward_charge", run.world.spawn.cell)
		assert(run:collect_pickup(pickup), "expected ward pickup to be collected")
		assert(run.player.consumables[1] == "ward_charge", "expected consumable in first slot")
		run:use_consumable(1)
		local before = run.player.health
		run:damage_player(2, "test")
		assert(run.player.health == before, "ward should prevent the next hit")
		assert(run.stats.wards_triggered == 1, "expected ward trigger stat")
	end,

	["codex fragments can reveal lore clue secrets"] = function()
		local run = Run.new("stalker", 33)
		run.world.secret_walls = {
			{
				reveal_method = "lore_clue",
				required_fragment = 1,
				revealed = false,
				cell_a = { x = 1, y = 1 },
				cell_b = { x = 2, y = 1 },
			},
		}
		run.codex:discover_fragment(1)
		run:refresh_secret_clues()
		assert(run.world.secret_walls[1].revealed == true, "expected lore clue reveal")
	end,

	["sprint runs record floor splits and category metadata"] = function()
		local run = Run.new("stalker", 41017, {}, nil, {
			mode = "sprint",
			sprint_ruleset = "official",
			sprint_seed_pack_id = "black_flame_circuit",
			sprint_seed_id = "ember_arc",
			category_key = "sprint:stalker:black_flame_circuit:ember_arc",
			official_record_eligible = true,
		})
		assert(run.splits[1].id == "floor_1_start", "expected first split at floor start")
		run.player.collected_torches = run.player.torch_goal
		run.player.inventory_torches = run.player.torch_goal
		run.player.x = run.world.exit.x
		run.player.y = run.world.exit.y
		run:interact()
		assert(run.split_index.floor_1_clear ~= nil, "expected floor clear split")
		assert(run.category_key == "sprint:stalker:black_flame_circuit:ember_arc", "expected sprint category key")
	end,

	["official sprint timer starts on first movement input"] = function()
		local run = Run.new("stalker", 41017, {}, nil, {
			mode = "sprint",
			sprint_ruleset = "official",
			sprint_seed_pack_id = "black_flame_circuit",
			sprint_seed_id = "ember_arc",
			official_record_eligible = true,
		})
		run:update(0.5)
		assert(run.clock == 0, "expected timer to stay armed before movement")
		run:keypressed("w")
		run:update(0.25)
		assert(run.timer_started == true, "expected timer start after movement")
		assert(run.timer_start_reason == "movement", "expected movement start reason")
		assert(run.clock == 0.25, "expected timer to advance after start")
	end,

	["burn dash and flare boost raise speed tech stats"] = function()
		local run = Run.new("stalker", 55)
		run.keys.w = true
		run.player.burst_charge = 1.0
		run.player.light_charge = 100
		run:release_burst()
		assert(run.stats.burn_dashes == 1, "expected burn dash stat")
		assert(run.player.dash_time > 0, "expected active dash window")

		run.player.angle = 0
		run:throw_flare()
		local flare = run.flares[#run.flares]
		run.player.x = flare.x
		run.player.y = flare.y
		run:update_flares(0.1)
		assert(run.stats.flare_boosts == 1, "expected flare boost stat")
		assert(run.player.speed_boost_time > 0, "expected flare boost timer")
	end,

	["sprint practice starts from floor snapshots"] = function()
		local run = Run.new("stalker", 41017, {}, nil, {
			mode = "sprint",
			sprint_ruleset = "practice",
			practice_target = "floor:3",
			start_floor = 3,
			loadout = "default",
		})
		assert(run.floor == 3, "expected direct practice floor start")
		assert(run.stats.floors_cleared >= 2, "expected prior floors counted for practice")
		assert(run.player.consumables[1] ~= nil, "expected practice consumable snapshot")
	end,

	["drill practice starts at authored route nodes"] = function()
		local run = Run.new("stalker", 41017, {}, nil, {
			mode = "sprint",
			sprint_ruleset = "practice",
			sprint_seed_pack_id = "black_flame_circuit",
			sprint_seed_id = "ember_arc",
			practice_target = "drill:black_flame_circuit:ember_arc:flare_line",
			start_floor = 2,
		})
		assert(run.practice_goal ~= nil, "expected drill practice goal")
		assert(run.practice_goal.route_id == "flare_line_2", "expected flare line route id")
		assert(run.player.x ~= run.world.spawn.x or run.player.y ~= run.world.spawn.y, "expected drill reposition from spawn")
	end,
}
