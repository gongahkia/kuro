local Settings = {}

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
		total_runs = 0,
		total_victories = 0,
	}
end

function Settings.load()
	if love and love.filesystem and love.filesystem.getInfo("settings.lua") then
		local chunk, err = love.filesystem.load("settings.lua")
		if chunk then
			local ok, data = pcall(chunk)
			if ok and type(data) == "table" then
				local defaults = Settings.default()
				for k, v in pairs(defaults) do
					if data[k] == nil then data[k] = v end
				end
				return data
			end
		end
	end
	return Settings.default()
end

function Settings.save(settings)
	if not (love and love.filesystem) then return false end
	local lines = { "return {" }
	for k, v in pairs(settings) do
		if type(v) == "boolean" then
			lines[#lines + 1] = string.format("\t%s = %s,", k, tostring(v))
		elseif type(v) == "number" then
			lines[#lines + 1] = string.format("\t%s = %s,", k, tostring(v))
		elseif type(v) == "string" then
			lines[#lines + 1] = string.format("\t%s = %q,", k, v)
		elseif type(v) == "table" then
			lines[#lines + 1] = string.format("\t%s = {},", k) -- shallow tables only
		end
	end
	lines[#lines + 1] = "}"
	return love.filesystem.write("settings.lua", table.concat(lines, "\n"))
end

return Settings
