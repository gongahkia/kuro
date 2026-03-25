local Sprint = require("src.game.sprint")

return {
	["sprint packs expose routes and practice targets"] = function()
		local pack = Sprint.get_pack("black_flame_circuit")
		assert(pack.version == "1.1.0", "expected pack version")
		local manifest = Sprint.get_route_manifest("black_flame_circuit", "ember_arc", 1)
		assert(manifest.minimum_torch.pickup_room == 1, "expected authored minimum torch room")
		assert(manifest.flare_line.checkpoint_count == 2, "expected authored flare checkpoints")
		assert(manifest.burn_lane.gate_count == 2, "expected authored burn gates")
		local targets = Sprint.list_practice_targets("black_flame_circuit", "ember_arc")
		assert(#targets >= 7, "expected floor targets plus drills")
	end,

	["sprint category keys and medals are deterministic"] = function()
		local key = Sprint.category_key("stalker", "black_flame_circuit", "ember_arc")
		assert(key == "sprint:stalker:black_flame_circuit:ember_arc", "expected stable category key")
		assert(Sprint.evaluate_medal("black_flame_circuit", "ember_arc", "stalker", 170) == "gold", "expected gold pace")
	end,

	["sprint practice summaries never update official records"] = function()
		local summary = {
			mode = "sprint",
			sprint_ruleset = "practice",
			outcome = "victory",
			official_record_eligible = false,
			duration = 100,
		}
		local records, result = Sprint.update_record({}, summary)
		assert(next(records) == nil, "practice should not mutate official records")
		assert(result.eligible == false, "practice summary should be ineligible")
	end,

	["sprint records keep best total and best split table"] = function()
		local summary = {
			mode = "sprint",
			sprint_ruleset = "official",
			sprint_seed_pack_id = "black_flame_circuit",
			sprint_seed_id = "ember_arc",
			difficulty_id = "stalker",
			pack_version = "1.0.0",
			build_id = "build_a",
			outcome = "victory",
			official_record_eligible = true,
			duration = 190,
			splits = {
				{ id = "floor_1_clear", label = "Floor 1 Clear", floor = 1, time = 60 },
				{ id = "run_finish", label = "Run Finish", floor = 3, time = 190 },
			},
		}
		local records, result = Sprint.update_record({}, summary, "pb_file.txt")
		assert(result.new_pb == true, "first official run should become the pb")
		assert(records[result.category_key].best_time == 190, "expected stored pb time")
		assert(records[result.category_key].best_time_pack_version == "1.0.0", "expected stored pb version")
		assert(records[result.category_key].best_time_build_id == "build_a", "expected stored pb build id")
		assert(records[result.category_key].pb_replay == "pb_file.txt", "expected stored pb replay")

		local slower = {
			mode = "sprint",
			sprint_ruleset = "official",
			sprint_seed_pack_id = "black_flame_circuit",
			sprint_seed_id = "ember_arc",
			difficulty_id = "stalker",
			pack_version = "1.1.0",
			build_id = "build_b",
			outcome = "victory",
			official_record_eligible = true,
			duration = 194,
			splits = {
				{ id = "floor_1_clear", label = "Floor 1 Clear", floor = 1, time = 58 },
				{ id = "run_finish", label = "Run Finish", floor = 3, time = 194 },
			},
		}
		local updated, next_result = Sprint.update_record(records, slower)
		assert(next_result.new_pb == false, "slower total should not replace pb time")
		assert(next_result.new_best_splits == true, "faster first split should update best split table")
		assert(updated[next_result.category_key].best_splits[1].time == 58, "expected improved split time")
		assert(updated[next_result.category_key].best_splits[1].pack_version == "1.1.0", "expected split provenance update")
		assert(updated[next_result.category_key].best_time == 190, "expected pb total to remain unchanged")
		assert(updated[next_result.category_key].best_time_pack_version == "1.0.0", "expected pb version to stay legacy")
		assert(updated[next_result.category_key].best_possible_time ~= nil, "expected best possible time")
		assert(type(updated[next_result.category_key].projected_saves) == "table", "expected projected save table")
		assert(updated[next_result.category_key].mixed_split_versions == true, "expected mixed split warning")
	end,

	["practice records track drill bests locally"] = function()
		local records = Sprint.update_practice_record({}, {
			mode = "sprint",
			sprint_ruleset = "practice",
			outcome = "victory",
			practice_target = "drill:black_flame_circuit:ember_arc:flare_line",
			practice_target_label = "Flare Line Drill",
			duration = 28.5,
		})
		assert(records["drill:black_flame_circuit:ember_arc:flare_line"].best_time == 28.5, "expected practice best time")
	end,
}
