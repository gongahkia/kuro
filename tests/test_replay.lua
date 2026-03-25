local files = {}
local directories = {}

_G.love = {
	filesystem = {
		createDirectory = function(path)
			directories[path] = true
		end,
		getDirectoryItems = function(path)
			local items = {}
			for file_path in pairs(files) do
				local item = file_path:match("^" .. path .. "/(.+)$")
				if item then
					items[#items + 1] = item
				end
			end
			table.sort(items)
			return items
		end,
		read = function(path)
			return files[path]
		end,
		write = function(path, contents)
			files[path] = contents
			return true
		end,
		getInfo = function(path)
			if directories[path] or files[path] then
				return { type = directories[path] and "directory" or "file" }
			end
			return nil
		end,
	},
}

package.loaded["src.game.replay"] = nil
local Replay = require("src.game.replay")

local suite = {
	["replay records saves and inspects context"] = function()
		Replay.init()
		Replay.start_recording(12345, "stalker", {
			mode = "sprint",
			sprint_ruleset = "official",
			sprint_seed_pack_id = "black_flame_circuit",
			sprint_seed_id = "ember_arc",
			pack_version = "1.0.0",
			practice_target = "",
			loadout = "scout",
		})
		Replay.record_key_state("w", true, 0.1)
		Replay.record_ghost_frame(0.1, 1, 2.5, 3.5)
		Replay.record_ghost_frame(0.4, 1, 3.0, 4.0)
		Replay.set_summary({
			splits = {
				{ id = "floor_1_clear", label = "Floor 1 Clear", floor = 1, time = 45.5, delta = -1.2 },
			},
			category_key = "sprint:stalker:black_flame_circuit:ember_arc",
			sprint_seed_pack_id = "black_flame_circuit",
			sprint_seed_id = "ember_arc",
			sprint_ruleset = "official",
			pack_version = "1.0.0",
			practice_target = "",
			medal = "gold",
			timer_start_reason = "movement",
			tech_usage = {
				burn_dashes = 2,
				flare_boosts = 1,
			},
			route_events = {
				burn_lane_dashes = 1,
			},
		})
		Replay.set_metadata({
			pb = true,
			restart_reason = "pb_finish",
		})
		Replay.record_key_state("w", false, 0.6)
		Replay.stop_recording()

		assert(Replay.save("spec_run"), "expected replay save")
		local replay = Replay.inspect("spec_run")
		assert(replay.seed == 12345, "expected replay seed")
		assert(replay.context.mode == "sprint", "expected replay mode context")
		assert(replay.context.sprint_seed_id == "ember_arc", "expected sprint seed context")
		assert(replay.context.loadout == "scout", "expected replay loadout context")
		assert(replay.metadata.pack_version == "1.0.0", "expected pack version metadata")
		assert(replay.metadata.timer_start_reason == "movement", "expected timer start metadata")
		assert(replay.metadata.pb == true, "expected pb metadata")
		assert(replay.metadata.category_key == "sprint:stalker:black_flame_circuit:ember_arc", "expected category metadata")
		assert(replay.metadata.tech_usage.burn_dashes == 2, "expected tech usage metadata")
		assert(replay.metadata.route_events.burn_lane_dashes == 1, "expected route event metadata")
		assert(#replay.splits == 1, "expected split table persistence")
		assert(#replay.ghost_frames == 2, "expected stored ghost frames")
	end,

	["replay playback returns inputs in order"] = function()
		Replay.init()
		Replay.start_recording(77, "nightmare")
		Replay.record_key_state("space", true, 0.1)
		Replay.record_key_state("space", false, 0.2)
		Replay.stop_recording()
		assert(Replay.save("timing"), "expected replay save")
		assert(Replay.load("timing"), "expected replay load")
		assert(Replay.start_playback(), "expected playback start")

		Replay.update(0.1)
		local first = Replay.get_next_input()
		assert(first.type == "keydown" and first.key == "space", "expected initial keydown")

		Replay.update(0.1)
		local second = Replay.get_next_input()
		assert(second.type == "keyup" and second.key == "space", "expected second keyup")
	end,
}

return suite
