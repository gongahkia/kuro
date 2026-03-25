local Settings = {}

local function deep_merge(defaults, data)
	if type(defaults) ~= "table" then
		if data == nil then
			return defaults
		end
		return data
	end

	local merged = {}
	for key, value in pairs(defaults) do
		merged[key] = deep_merge(value, type(data) == "table" and data[key] or nil)
	end
	if type(data) == "table" then
		for key, value in pairs(data) do
			if merged[key] == nil then
				merged[key] = value
			end
		end
	end
	return merged
end

local function sorted_keys(tbl)
	local keys = {}
	for key in pairs(tbl) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(left, right)
		if type(left) == type(right) then
			return tostring(left) < tostring(right)
		end
		return type(left) < type(right)
	end)
	return keys
end

local function serialize_key(key)
	if type(key) == "string" and key:match("^[_%a][_%w]*$") then
		return key
	end
	if type(key) == "number" then
		return "[" .. tostring(key) .. "]"
	end
	return "[" .. string.format("%q", tostring(key)) .. "]"
end

local function serialize_value(value, indent)
	indent = indent or ""
	if type(value) == "boolean" or type(value) == "number" then
		return tostring(value)
	end
	if type(value) == "string" then
		return string.format("%q", value)
	end
	if type(value) ~= "table" then
		return "nil"
	end
	if next(value) == nil then
		return "{}"
	end

	local next_indent = indent .. "\t"
	local lines = { "{" }
	for _, key in ipairs(sorted_keys(value)) do
		lines[#lines + 1] = string.format("%s%s = %s,", next_indent, serialize_key(key), serialize_value(value[key], next_indent))
	end
	lines[#lines + 1] = indent .. "}"
	return table.concat(lines, "\n")
end

function Settings.default()
		return {
			screen_shake = true,
			flash_on_kill = true,
			pulse_light = true,
			death_animations = true,
		footstep_bob = true,
		title_flicker = true,
		master_volume = 0.7,
		sfx_volume = 1.0,
		ambient_volume = 0.8,
			meta_unlocks = {},
			selected_mode = "classic",
			selected_loadout = "default",
			selected_flame_color = "amber",
			selected_sprint_ruleset = "official",
			selected_sprint_pack_id = "black_flame_circuit",
			selected_sprint_seed_id = "ember_arc",
			selected_sprint_practice_floor = 1,
			daily_records = {},
			time_attack_records = {},
			sprint_records = {},
			runner_ghost_visible = true,
			runner_auto_save_pb_replay = true,
			runner_restart_confirmation = true,
			runner_show_medal_pace = true,
			runner_show_split_delta = true,
			total_runs = 0,
			total_victories = 0,
			total_burns = 0,
			damageless_floor2 = false,
		}
end

function Settings.load()
	if love and love.filesystem and love.filesystem.getInfo("settings.lua") then
		local chunk, err = love.filesystem.load("settings.lua")
		if chunk then
			local ok, data = pcall(chunk)
			if ok and type(data) == "table" then
				return deep_merge(Settings.default(), data)
			end
		end
	end
	return Settings.default()
end

function Settings.save(settings)
	if not (love and love.filesystem) then return false end
	return love.filesystem.write("settings.lua", "return " .. serialize_value(settings or Settings.default(), "") .. "\n")
end

return Settings
