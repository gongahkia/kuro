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
	end,

	["app practice sprint wins leave official records untouched"] = function()
		local app, Replay = fresh_app()
		app:load({})
		app.selected_mode = "sprint"
		app.settings.selected_sprint_ruleset = "practice"
		app.settings.selected_sprint_seed_id = "random"
		app:start_run()
		Replay.record_key_state("w", true, 0.1)
		app.run.clock = 150
		app.run.splits = {
			{ id = "floor_3_start", label = "Floor 3 Start", floor = 3, time = 0 },
			{ id = "run_finish", label = "Run Finish", floor = 3, time = 150 },
		}
		app:record_result("victory")
		assert(next(app.settings.sprint_records) == nil, "practice should not create official sprint records")
	end,
}
