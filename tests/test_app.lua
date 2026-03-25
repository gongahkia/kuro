local files = {}
local directories = {}

local function install_love_mock()
	local source = {
		setLooping = function() end,
		setVolume = function() end,
		play = function() end,
		stop = function() end,
		isPlaying = function() return false end,
		clone = function(self) return self end,
	}

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
			load = function(path)
				return load(files[path])
			end,
		},
		math = {
			random = math.random,
		},
		event = {
			quit = function() end,
		},
		graphics = {
			getDimensions = function() return 1280, 720 end,
			getWidth = function() return 1280 end,
			getHeight = function() return 720 end,
			setColor = function() end,
			printf = function() end,
			print = function() end,
			rectangle = function() end,
			circle = function() end,
			line = function() end,
			clear = function() end,
			polygon = function() end,
			setScissor = function() end,
			getScissor = function() return nil end,
		},
		timer = {
			getTime = function() return 0 end,
		},
		audio = {
			newSource = function()
				return source
			end,
		},
	}
end

local function fresh_app()
	for key in pairs(files) do
		files[key] = nil
	end
	for key in pairs(directories) do
		directories[key] = nil
	end
	install_love_mock()
	package.loaded["src.app"] = nil
	package.loaded["src.game.replay"] = nil
	local App = require("src.app")
	local Replay = require("src.game.replay")
	return App.new(), Replay
end

return {
	["app records official sprint pbs and autosaves replay"] = function()
		local app, Replay = fresh_app()
		app:load({})
		app.selected_mode = "sprint"
		app.settings.selected_sprint_ruleset = "official"
		app:start_run()
		Replay.record_key_state("w", true, 0.1)
		app.run.clock = 170
		app.run.splits = {
			{ id = "floor_1_start", label = "Floor 1 Start", floor = 1, time = 0 },
			{ id = "run_finish", label = "Run Finish", floor = 3, time = 170 },
		}
		app:record_result("victory")
		local key = "sprint:stalker:black_flame_circuit:ember_arc"
		assert(app.settings.sprint_records[key].best_time == 170, "expected stored sprint pb")
		assert(files["replays/pb_sprint_stalker_black_flame_circuit_ember_arc.txt"], "expected autosaved pb replay")
		local found_finish_replay = false
		local found_export = false
		local found_json_export = false
		for path in pairs(files) do
			if path:match("^replays/run_") then
				found_finish_replay = true
			end
			if path:match("^exports/") then
				found_export = true
			end
			if path:match("^exports/.+%.json$") then
				found_json_export = true
			end
		end
		assert(found_finish_replay, "expected saved official finish replay")
		assert(found_export, "expected sprint export file")
		assert(found_json_export, "expected sprint json export file")
	end,

	["app keeps legacy sprint ghost comparisons active"] = function()
		local app, Replay = fresh_app()
		app:load({})
		local key = "sprint:stalker:black_flame_circuit:ember_arc"
		Replay.init()
		Replay.start_recording(4101, "stalker", {
			mode = "sprint",
			sprint_ruleset = "official",
			sprint_seed_pack_id = "black_flame_circuit",
			sprint_seed_id = "ember_arc",
			category_key = key,
			pack_version = "1.0.0",
		})
		Replay.record_key_state("w", true, 0.1)
		Replay.record_ghost_frame(0.1, 1, 2.5, 3.5)
		Replay.set_metadata({
			category_key = key,
			pack_version = "1.0.0",
			replay_file = "legacy_pb.txt",
		})
		Replay.stop_recording()
		assert(Replay.save("legacy_pb"), "expected saved legacy pb replay")

		app.settings.sprint_records[key] = {
			best_time = 170,
			best_time_pack_version = "1.0.0",
			best_splits = {
				{ id = "floor_1_clear", label = "Floor 1 Clear", floor = 1, time = 60, pack_version = "1.0.0" },
				{ id = "run_finish", label = "Run Finish", floor = 3, time = 170, pack_version = "1.1.0" },
			},
			mixed_split_versions = true,
			pb_replay = "legacy_pb.txt",
		}

		app.selected_mode = "sprint"
		app.settings.selected_sprint_ruleset = "official"
		app:start_run()

		assert(app.run.ghost_compare ~= nil, "expected legacy ghost comparison to load")
		assert(app.run.pb_pack_version == "1.0.0", "expected stored pb version on run")
		assert(app.run.pack_version_mismatch == true, "expected legacy comparison warning")
		assert(app.run.mixed_split_versions == true, "expected mixed split warning on run")
	end,

	["app saves final official sprint replay metadata"] = function()
		local app, Replay = fresh_app()
		app:load({})
		local key = "sprint:stalker:black_flame_circuit:ember_arc"
		app.settings.sprint_records[key] = {
			best_time = 170,
			best_time_pack_version = "1.0.0",
			best_time_build_id = "legacy_build",
			best_medal = "gold",
			best_splits = {
				{ id = "floor_1_clear", label = "Floor 1 Clear", floor = 1, time = 60, pack_version = "1.0.0" },
				{ id = "run_finish", label = "Run Finish", floor = 3, time = 170, pack_version = "1.0.0" },
			},
			pb_replay = "legacy_pb.txt",
		}

		Replay.init()
		Replay.start_recording(4101, "stalker", {
			mode = "sprint",
			sprint_ruleset = "official",
			sprint_seed_pack_id = "black_flame_circuit",
			sprint_seed_id = "ember_arc",
			category_key = key,
			pack_version = "1.0.0",
		})
		Replay.record_key_state("w", true, 0.1)
		Replay.record_ghost_frame(0.1, 1, 2.5, 3.5)
		Replay.set_metadata({
			category_key = key,
			pack_version = "1.0.0",
			replay_file = "legacy_pb.txt",
		})
		Replay.stop_recording()
		assert(Replay.save("legacy_pb"), "expected saved legacy pb replay")

		app.selected_mode = "sprint"
		app.settings.selected_sprint_ruleset = "official"
		app:start_run()
		Replay.record_key_state("w", true, 0.1)
		app.run.clock = 172
		app.run.splits = {
			{ id = "floor_1_start", label = "Floor 1 Start", floor = 1, time = 0 },
			{ id = "floor_1_clear", label = "Floor 1 Clear", floor = 1, time = 58 },
			{ id = "run_finish", label = "Run Finish", floor = 3, time = 172 },
		}
		app:record_result("victory")

		local finish_path = nil
		for path in pairs(files) do
			if path:match("^replays/run_") then
				finish_path = path
			end
		end
		assert(finish_path ~= nil, "expected saved official finish replay")
		local finish_replay = Replay.inspect(finish_path)
		assert(finish_replay.metadata.replay_file == finish_path:match("^replays/(.+)$"), "expected saved replay filename metadata")
		assert(finish_replay.metadata.pb_pack_version == "1.0.0", "expected legacy pb provenance in replay metadata")
		assert(finish_replay.metadata.pack_version_mismatch == true, "expected replay mismatch warning")
		assert(finish_replay.metadata.mixed_split_versions == true, "expected replay mixed split warning")
		assert(finish_replay.metadata.best_possible_time == 170, "expected final best possible time in replay metadata")
		assert(type(finish_replay.metadata.projected_saves) == "table", "expected projected saves in replay metadata")
		assert(app.settings.sprint_records[key].best_time == 170, "expected official pb to remain legacy")
		assert(app.settings.sprint_records[key].best_time_pack_version == "1.0.0", "expected pb version to remain legacy")
	end,

	["app practice sprint wins leave official records untouched"] = function()
		local app, Replay = fresh_app()
		app:load({})
		app.selected_mode = "sprint"
		app.settings.selected_sprint_ruleset = "practice"
		app.settings.selected_sprint_seed_id = "ember_arc"
		app.settings.selected_sprint_practice_target = "drill:black_flame_circuit:ember_arc:flare_line"
		app:start_run()
		Replay.record_key_state("w", true, 0.1)
		app.run.clock = 150
		app.run.splits = {
			{ id = "floor_2_start", label = "Floor 2 Start", floor = 2, time = 0 },
			{ id = "run_finish", label = "Run Finish", floor = 2, time = 150 },
		}
		app:record_result("victory")
		assert(next(app.settings.sprint_records) == nil, "practice should not create official sprint records")
		assert(app.settings.sprint_practice_records["drill:black_flame_circuit:ember_arc:flare_line"].best_time == 150, "expected local drill best")
	end,
}
