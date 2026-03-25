local Sprint = require("src.game.sprint")

return {
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
		assert(records[result.category_key].pb_replay == "pb_file.txt", "expected stored pb replay")

		local slower = {
			mode = "sprint",
			sprint_ruleset = "official",
			sprint_seed_pack_id = "black_flame_circuit",
			sprint_seed_id = "ember_arc",
			difficulty_id = "stalker",
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
		assert(updated[next_result.category_key].best_time == 190, "expected pb total to remain unchanged")
	end,
}
