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
			mode = "daily",
			loadout = "scout",
		})
		Replay.record_key_state("w", true, 0.1)
		Replay.record_key_state("w", false, 0.6)
		Replay.stop_recording()

		assert(Replay.save("spec_run"), "expected replay save")
		local replay = Replay.inspect("spec_run")
		assert(replay.seed == 12345, "expected replay seed")
		assert(replay.context.mode == "daily", "expected replay mode context")
		assert(replay.context.loadout == "scout", "expected replay loadout context")
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
