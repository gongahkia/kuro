local util = require("src.core.util")

local Replay = {}

local FILE_VERSION = "2.0"
local REPLAY_DIR = "replays"
local GHOST_SAMPLE_INTERVAL = 0.25

local recording = false
local playing = false
local playback_index = 1
local playback_time = 0
local current_recording_time = 0
local last_ghost_sample_time = -GHOST_SAMPLE_INTERVAL

local function new_replay_data(seed, difficulty)
	return {
		version = FILE_VERSION,
		seed = seed,
		difficulty = difficulty or "stalker",
		context = {},
		inputs = {},
		splits = {},
		ghost_frames = {},
		metadata = {
			recording_date = os.date("%Y-%m-%d %H:%M:%S"),
			duration = 0,
			total_inputs = 0,
			pb = false,
			restart_reason = "",
			category_key = "",
			seed_pack_id = "",
			seed_id = "",
			ruleset = "",
			medal = "",
			tech_usage = {},
		},
	}
end

local replay_data = new_replay_data(nil, nil)

local function deep_copy(value)
	if type(value) ~= "table" then
		return value
	end
	return util.deepcopy(value)
end

local function get_filesystem()
	if love and love.filesystem then
		return {
			create_directory = function(path)
				love.filesystem.createDirectory(path)
			end,
			get_directory_items = function(path)
				return love.filesystem.getDirectoryItems(path)
			end,
			read = function(path)
				return love.filesystem.read(path)
			end,
			write = function(path, contents)
				return love.filesystem.write(path, contents)
			end,
			exists = function(path)
				return love.filesystem.getInfo(path) ~= nil
			end,
		}
	end

	return {
		create_directory = function(path)
			os.execute(string.format('mkdir -p "%s"', path))
		end,
		get_directory_items = function(path)
			local items = {}
			local handle = io.popen(string.format('ls -1 "%s" 2>/dev/null', path))
			if not handle then
				return items
			end
			for file in handle:lines() do
				items[#items + 1] = file
			end
			handle:close()
			return items
		end,
		read = function(path)
			local handle = io.open(path, "r")
			if not handle then
				return nil
			end
			local contents = handle:read("*all")
			handle:close()
			return contents
		end,
		write = function(path, contents)
			local handle = io.open(path, "w")
			if not handle then
				return false
			end
			handle:write(contents)
			handle:close()
			return true
		end,
		exists = function(path)
			local handle = io.open(path, "r")
			if handle then
				handle:close()
				return true
			end
			return false
		end,
	}
end

local function normalize_filename(filename)
	filename = filename or string.format("replay_%s.txt", os.date("%Y%m%d_%H%M%S"))
	if not filename:match("%.txt$") then
		filename = filename .. ".txt"
	end
	return filename
end

local function sanitize_filename(value)
	return tostring(value or "replay"):gsub("[^%w%-_]+", "_")
end

local function serialize_path(lines, prefix, value, header)
	if type(value) ~= "table" then
		lines[#lines + 1] = string.format("%s:%s=%s", header, prefix, tostring(value))
		return
	end
	for key, inner in pairs(value) do
		local next_prefix = prefix ~= "" and (prefix .. "." .. key) or tostring(key)
		serialize_path(lines, next_prefix, inner, header)
	end
end

local function serialize(data)
	local metadata = data.metadata or {}
	local lines = {
		"VERSION:" .. tostring(data.version or FILE_VERSION),
		"SEED:" .. tostring(data.seed or ""),
		"DIFFICULTY:" .. tostring(data.difficulty or "stalker"),
		"DATE:" .. tostring(metadata.recording_date or ""),
		"DURATION:" .. tostring(metadata.duration or 0),
		"TOTAL_INPUTS:" .. tostring(metadata.total_inputs or #data.inputs),
	}
	for _, key in ipairs({ "pb", "restart_reason", "category_key", "seed_pack_id", "seed_id", "ruleset", "medal" }) do
		lines[#lines + 1] = string.format("META:%s=%s", key, tostring(metadata[key] or ""))
	end
	serialize_path(lines, "", data.context or {}, "CONTEXT")
	serialize_path(lines, "", metadata.tech_usage or {}, "TECH")
	lines[#lines + 1] = "SPLITS:"
	for _, split in ipairs(data.splits or {}) do
		lines[#lines + 1] = string.format("%s|%s|%s|%.4f|%s", split.id or "", split.label or "", tostring(split.floor or ""), split.time or 0, split.delta ~= nil and tostring(split.delta) or "")
	end
	lines[#lines + 1] = "GHOST:"
	for _, frame in ipairs(data.ghost_frames or {}) do
		lines[#lines + 1] = string.format("%.4f|%d|%.4f|%.4f", frame.timestamp or 0, frame.floor or 1, frame.x or 0, frame.y or 0)
	end
	lines[#lines + 1] = "INPUTS:"
	for _, input in ipairs(data.inputs or {}) do
		lines[#lines + 1] = string.format("%s|%s|%.4f", input.type, input.key, input.timestamp)
	end
	return table.concat(lines, "\n")
end

local function deserialize_lua(contents)
	if not contents or not contents:match("^return%s+") then
		return nil
	end
	local chunk, err = load(contents)
	if not chunk then
		return nil, err
	end
	local ok, data = pcall(chunk)
	if ok and type(data) == "table" then
		return data
	end
	return nil
end

local function deserialize_text(contents)
	if not contents or contents == "" then
		return nil
	end

	local replay = new_replay_data(nil, "stalker")
	replay.metadata.recording_date = ""
	local section = nil

	local function coerce(value)
		if value == "true" then
			return true
		elseif value == "false" then
			return false
		elseif value == "" then
			return ""
		end
		return tonumber(value) or value
	end

	local function assign_nested(target, path, value)
		local current = target
		local parts = {}
		for part in path:gmatch("[^%.]+") do
			parts[#parts + 1] = part
		end
		for index = 1, #parts - 1 do
			local part = parts[index]
			if type(current[part]) ~= "table" then
				current[part] = {}
			end
			current = current[part]
		end
		if #parts > 0 then
			current[parts[#parts]] = coerce(value)
		end
	end

	for line in contents:gmatch("[^\r\n]+") do
		if line == "SPLITS:" then
			section = "splits"
		elseif line == "GHOST:" then
			section = "ghost"
		elseif line == "INPUTS:" then
			section = "inputs"
		elseif section == "splits" then
			local id, label, floor, time_value, delta = line:match("([^|]*)|([^|]*)|([^|]*)|([^|]*)|?(.*)")
			if id and label and floor and time_value then
				replay.splits[#replay.splits + 1] = {
					id = id,
					label = label,
					floor = tonumber(floor) or 1,
					time = tonumber(time_value) or 0,
					delta = delta ~= "" and (tonumber(delta) or delta) or nil,
				}
			end
		elseif section == "ghost" then
			local timestamp, floor, x, y = line:match("([^|]+)|([^|]+)|([^|]+)|([^|]+)")
			if timestamp and floor and x and y then
				replay.ghost_frames[#replay.ghost_frames + 1] = {
					timestamp = tonumber(timestamp) or 0,
					floor = tonumber(floor) or 1,
					x = tonumber(x) or 0,
					y = tonumber(y) or 0,
				}
			end
		elseif section == "inputs" then
			local input_type, key, timestamp = line:match("([^|]+)|([^|]+)|([%d%.%-]+)")
			if input_type and key and timestamp then
				replay.inputs[#replay.inputs + 1] = {
					type = input_type,
					key = key,
					timestamp = tonumber(timestamp) or 0,
				}
			end
		else
			local key, value = line:match("([^:]+):(.*)")
			if key and value then
				if key == "VERSION" then
					replay.version = value
				elseif key == "SEED" then
					replay.seed = tonumber(value) or value
				elseif key == "DIFFICULTY" then
					replay.difficulty = value
				elseif key == "DATE" then
					replay.metadata.recording_date = value
				elseif key == "DURATION" then
					replay.metadata.duration = tonumber(value) or 0
				elseif key == "TOTAL_INPUTS" then
					replay.metadata.total_inputs = tonumber(value) or 0
				elseif key == "META" then
					local path, raw_value = value:match("^([%w_%.]+)=(.*)$")
					if path then
						assign_nested(replay.metadata, path, raw_value)
					end
				elseif key == "CONTEXT" then
					local path, raw_value = value:match("^([%w_%.]+)=(.*)$")
					if path then
						assign_nested(replay.context, path, raw_value)
					end
				elseif key == "TECH" then
					local path, raw_value = value:match("^([%w_%.]+)=(.*)$")
					if path then
						assign_nested(replay.metadata.tech_usage, path, raw_value)
					end
				end
			end
		end
	end

	replay.metadata.total_inputs = replay.metadata.total_inputs or #replay.inputs
	return replay
end

local function deserialize(contents)
	local replay = deserialize_lua(contents)
	if replay then
		return replay
	end
	return deserialize_text(contents)
end

function Replay.init()
	local fs = get_filesystem()
	fs.create_directory(REPLAY_DIR)
	recording = false
	playing = false
	playback_index = 1
	playback_time = 0
	current_recording_time = 0
	last_ghost_sample_time = -GHOST_SAMPLE_INTERVAL
	replay_data = new_replay_data(nil, nil)
end

function Replay.start_recording(seed, difficulty, context)
	replay_data = new_replay_data(seed, difficulty)
	replay_data.context = deep_copy(context or {})
	recording = true
	playing = false
	playback_index = 1
	playback_time = 0
	current_recording_time = 0
	last_ghost_sample_time = -GHOST_SAMPLE_INTERVAL
end

function Replay.stop_recording()
	if not recording then
		return
	end
	recording = false
	replay_data.metadata.duration = current_recording_time
	replay_data.metadata.total_inputs = #replay_data.inputs
end

function Replay.record_key_state(key, is_down, timestamp)
	if not recording then
		return
	end
	replay_data.inputs[#replay_data.inputs + 1] = {
		type = is_down and "keydown" or "keyup",
		key = key,
		timestamp = timestamp or current_recording_time,
	}
end

function Replay.record_ghost_frame(timestamp, floor, x, y)
	if not recording then
		return
	end
	local capture_time = timestamp or current_recording_time
	if capture_time - last_ghost_sample_time < GHOST_SAMPLE_INTERVAL then
		return
	end
	last_ghost_sample_time = capture_time
	replay_data.ghost_frames[#replay_data.ghost_frames + 1] = {
		timestamp = capture_time,
		floor = floor or 1,
		x = x or 0,
		y = y or 0,
	}
end

function Replay.set_summary(summary)
	if not replay_data or not summary then
		return
	end
	replay_data.splits = deep_copy(summary.splits or {})
	replay_data.metadata.category_key = summary.category_key or replay_data.metadata.category_key
	replay_data.metadata.seed_pack_id = summary.sprint_seed_pack_id or replay_data.metadata.seed_pack_id
	replay_data.metadata.seed_id = summary.sprint_seed_id or replay_data.metadata.seed_id
	replay_data.metadata.ruleset = summary.sprint_ruleset or replay_data.metadata.ruleset
	replay_data.metadata.medal = summary.medal or replay_data.metadata.medal
	replay_data.metadata.tech_usage = deep_copy(summary.tech_usage or {})
end

function Replay.set_metadata(values)
	if not replay_data or type(values) ~= "table" then
		return
	end
	for key, value in pairs(values) do
		if key == "tech_usage" and type(value) == "table" then
			replay_data.metadata.tech_usage = deep_copy(value)
		else
			replay_data.metadata[key] = value
		end
	end
end

function Replay.update(dt)
	if recording then
		current_recording_time = current_recording_time + dt
	end
	if playing then
		playback_time = playback_time + dt
	end
end

function Replay.save(filename)
	if not replay_data or #replay_data.inputs == 0 then
		return false
	end
	local fs = get_filesystem()
	local normalized = normalize_filename(filename)
	local path = REPLAY_DIR .. "/" .. normalized
	replay_data.metadata.duration = current_recording_time > 0 and current_recording_time or replay_data.metadata.duration
	replay_data.metadata.total_inputs = #replay_data.inputs
	return fs.write(path, serialize(replay_data))
end

function Replay.pb_filename(category_key)
	return "pb_" .. sanitize_filename(category_key) .. ".txt"
end

function Replay.load(filename)
	local fs = get_filesystem()
	local path = filename:match("^" .. REPLAY_DIR .. "/") and filename or (REPLAY_DIR .. "/" .. normalize_filename(filename))
	if not fs.exists(path) then
		return false
	end
	local parsed = deserialize(fs.read(path))
	if not parsed then
		return false
	end
	replay_data = parsed
	recording = false
	playing = false
	playback_index = 1
	playback_time = 0
	current_recording_time = 0
	last_ghost_sample_time = -GHOST_SAMPLE_INTERVAL
	return true
end

function Replay.inspect(filename)
	local fs = get_filesystem()
	local path = filename:match("^" .. REPLAY_DIR .. "/") and filename or (REPLAY_DIR .. "/" .. normalize_filename(filename))
	if not fs.exists(path) then
		return nil
	end
	return deserialize(fs.read(path))
end

function Replay.start_playback()
	if not replay_data or #replay_data.inputs == 0 then
		return false
	end
	recording = false
	playing = true
	playback_index = 1
	playback_time = 0
	current_recording_time = 0
	return true
end

function Replay.stop_playback()
	playing = false
	playback_index = 1
	playback_time = 0
end

function Replay.get_next_input()
	if not playing or playback_index > #replay_data.inputs then
		return nil
	end
	local input = replay_data.inputs[playback_index]
	if input.timestamp <= playback_time then
		playback_index = playback_index + 1
		if playback_index > #replay_data.inputs then
			playing = false
		end
		return input
	end
	return nil
end

function Replay.is_recording()
	return recording
end

function Replay.is_playing()
	return playing
end

function Replay.has_data()
	return replay_data ~= nil and #replay_data.inputs > 0
end

function Replay.get_context()
	return replay_data.context
end

function Replay.get_metadata()
	return replay_data.metadata
end

function Replay.get_data()
	return replay_data
end

function Replay.get_playback_progress()
	local duration = replay_data and replay_data.metadata and replay_data.metadata.duration or 0
	if duration <= 0 then
		return 0
	end
	return math.min(1, playback_time / duration)
end

function Replay.list_replays()
	local fs = get_filesystem()
	fs.create_directory(REPLAY_DIR)
	local items = {}
	for _, file in ipairs(fs.get_directory_items(REPLAY_DIR)) do
		if file:match("%.txt$") then
			items[#items + 1] = file
		end
	end
	table.sort(items, function(left, right)
		return left > right
	end)
	return items
end

return Replay
