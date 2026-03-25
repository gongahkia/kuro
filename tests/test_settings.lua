local Settings = require("src.core.settings")

return {
	["settings default returns table with all keys"] = function()
		local d = Settings.default()
		assert(type(d) == "table", "expected table")
		assert(d.screen_shake == true, "expected screen_shake true")
		assert(d.death_animations == true, "expected death_animations true")
		assert(d.footstep_bob == true, "expected footstep_bob true")
		assert(d.title_flicker == true, "expected title_flicker true")
		assert(type(d.master_volume) == "number", "expected master_volume number")
		assert(type(d.meta_unlocks) == "table", "expected meta_unlocks table")
		assert(d.selected_sprint_ruleset == "official", "expected official sprint default")
		assert(d.selected_sprint_practice_target == "floor:1", "expected floor practice target default")
		assert(d.runner_ghost_visible == true, "expected ghost visibility enabled")
		assert(d.runner_practice_auto_restart == false, "expected practice auto restart disabled")
		assert(d.total_runs == 0, "expected total_runs 0")
	end,
	["settings default values are independent copies"] = function()
		local a = Settings.default()
		local b = Settings.default()
		a.screen_shake = false
		assert(b.screen_shake == true, "expected independent copy")
	end,
	["settings save and load nested tables"] = function()
		local original_love = _G.love
		local stored = nil
		_G.love = {
			filesystem = {
				getInfo = function(path)
					return path == "settings.lua" and stored and { type = "file" } or nil
				end,
				load = function(path)
					assert(path == "settings.lua", "unexpected settings path")
					return load(stored)
				end,
				write = function(path, contents)
					assert(path == "settings.lua", "unexpected settings write path")
					stored = contents
					return true
				end,
			},
		}

			local settings = Settings.default()
			settings.meta_unlocks.mutator_ironman = true
			settings.time_attack_records.stalker = 91.5
			settings.sprint_records["sprint:stalker:black_flame_circuit:ember_arc"] = {
				best_time = 170.2,
			}
			settings.sprint_practice_records["drill:black_flame_circuit:ember_arc:flare_line"] = {
				best_time = 31.4,
			}
			assert(Settings.save(settings), "expected settings save")
			local loaded = Settings.load()
			assert(loaded.meta_unlocks.mutator_ironman == true, "expected nested unlock persistence")
			assert(loaded.time_attack_records.stalker == 91.5, "expected nested record persistence")
			assert(loaded.sprint_records["sprint:stalker:black_flame_circuit:ember_arc"].best_time == 170.2, "expected sprint record persistence")
			assert(loaded.sprint_practice_records["drill:black_flame_circuit:ember_arc:flare_line"].best_time == 31.4, "expected drill record persistence")
			_G.love = original_love
		end,
	}
