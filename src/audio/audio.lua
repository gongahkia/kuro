local util = require("src.core.util")

local Audio = {}
Audio.__index = Audio

function Audio.new(settings)
	return setmetatable({
		settings = settings or {},
		sources = {},
		ambient_source = nil,
		music_source = nil,
		listener = { x = 0, y = 0, angle = 0 },
		loaded = false,
		wind_source = nil,
		wind_volume = 0,
		wind_target = 0,
	}, Audio)
end

function Audio:load_manifest(manifest)
	if not (love and love.audio) then return end
	for _, entry in ipairs(manifest) do
		local info = love.filesystem.getInfo(entry.path)
		if info then
			local mode = (entry.kind == "ambient" or entry.kind == "music") and "stream" or "static"
			local ok, source = pcall(love.audio.newSource, entry.path, mode)
			if ok then self.sources[entry.name] = { source = source, kind = entry.kind } end
		end
	end
	self.loaded = true
end

function Audio:set_listener(x, y, angle)
	self.listener.x = x
	self.listener.y = y
	self.listener.angle = angle
end

function Audio:play(name, opts)
	if not self.loaded then return end
	local entry = self.sources[name]
	if not entry then return end
	opts = opts or {}
	local source = entry.source:clone()
	local vol = (self.settings.master_volume or 0.7) * (self.settings.sfx_volume or 1.0) * (opts.volume or 1.0)
	if opts.x and opts.y then -- positional attenuation
		local dist = util.distance(self.listener.x, self.listener.y, opts.x, opts.y)
		vol = vol * util.clamp(1 - dist * 0.1, 0, 1)
		local angle_to = math.atan(opts.y - self.listener.y, opts.x - self.listener.x)
		local delta = ((angle_to - self.listener.angle + math.pi) % (math.pi * 2)) - math.pi
		local pan = util.clamp(math.sin(delta), -1, 1)
		if source.setPosition then
			source:setPosition(pan, 0, 0)
		end
	end
	source:setVolume(util.clamp(vol, 0, 1))
	if opts.pitch then source:setPitch(opts.pitch) end
	source:play()
end

function Audio:play_ambient(name)
	if not self.loaded then return end
	local entry = self.sources[name]
	if not entry then return end
	if self.ambient_source then
		self.ambient_source:stop()
	end
	local source = entry.source
	source:setLooping(true)
	source:setVolume((self.settings.master_volume or 0.7) * (self.settings.ambient_volume or 0.8))
	source:play()
	self.ambient_source = source
end

function Audio:play_music(name)
	if not self.loaded then return end
	local entry = self.sources[name]
	if not entry then return end
	if self.music_source then
		self.music_source:stop()
	end
	local source = entry.source
	source:setLooping(true)
	source:setVolume((self.settings.master_volume or 0.7) * (self.settings.sfx_volume or 1.0))
	source:play()
	self.music_source = source
end

function Audio:stop_all()
	if self.ambient_source then self.ambient_source:stop() end
	if self.music_source then self.music_source:stop() end
	if self.wind_source then self.wind_source:stop() end
end

function Audio:update(_dt)
	-- future: fade logic, positional source updates
end

function Audio:update_wind(dt, speed)
	if not self.loaded then return end
	if speed > 6 then
		self.wind_target = util.clamp((speed - 6) / 8, 0, 0.4) * (self.settings.master_volume or 0.7)
	else
		self.wind_target = 0
	end
	self.wind_volume = self.wind_volume + (self.wind_target - self.wind_volume) * math.min(1, 4.0 * dt)
	if not self.wind_source and self.sources["wind_loop"] then
		local entry = self.sources["wind_loop"]
		self.wind_source = entry.source:clone()
		self.wind_source:setLooping(true)
		self.wind_source:setVolume(0)
		self.wind_source:play()
	end
	if self.wind_source then
		self.wind_source:setVolume(util.clamp(self.wind_volume, 0, 1))
	end
end

return Audio
