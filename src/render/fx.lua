local util = require("src.core.util")

local FX = {}
FX.__index = FX
local JUMP_ARC_TIME = 0.65

function FX.new(settings)
	return setmetatable({
		settings = settings or {},
		shake_intensity = 0,
		shake_time = 0,
		shake_offset_x = 0,
		shake_offset_y = 0,
		bob_phase = 0,
		bob_amplitude = 0.012,
		kill_flashes = {},
		death_particles = {},
		low_charge_phase = 0,
	}, FX)
end

function FX:update(dt)
	if self.shake_time > 0 then -- screen shake decay
		self.shake_time = self.shake_time - dt
		local t = math.max(0, self.shake_time)
		self.shake_offset_x = (math.random() * 2 - 1) * self.shake_intensity * t
		self.shake_offset_y = (math.random() * 2 - 1) * self.shake_intensity * t
		if self.shake_time <= 0 then
			self.shake_offset_x = 0
			self.shake_offset_y = 0
		end
	end
	self.bob_phase = self.bob_phase + dt * 8.5 -- footstep bob
	self.low_charge_phase = self.low_charge_phase + dt * 3.2 -- low charge pulse
	for i = #self.kill_flashes, 1, -1 do -- kill flash decay
		local flash = self.kill_flashes[i]
		flash.ttl = flash.ttl - dt
		if flash.ttl <= 0 then table.remove(self.kill_flashes, i) end
	end
	for i = #self.death_particles, 1, -1 do -- death anim decay
		local p = self.death_particles[i]
		p.elapsed = p.elapsed + dt
		if p.elapsed >= p.duration then table.remove(self.death_particles, i) end
	end
end

function FX:trigger_shake(intensity, duration)
	if not self.settings.screen_shake then return end
	self.shake_intensity = math.max(self.shake_intensity, intensity)
	self.shake_time = math.max(self.shake_time, duration)
end

function FX:trigger_kill_flash(screen_x, screen_y)
	if not self.settings.flash_on_kill then return end
	self.kill_flashes[#self.kill_flashes + 1] = { x = screen_x, y = screen_y, ttl = 0.15, radius = 28 }
end

function FX:trigger_death_anim(screen_x, screen_y, kind)
	if not self.settings.death_animations then return end
	local color = { 0.86, 0.23, 0.22 } -- default stalker red
	if kind == "rusher" then color = { 0.95, 0.45, 0.24 }
	elseif kind == "leech" then color = { 0.76, 0.88, 0.95 }
	elseif kind == "sentry" then color = { 0.82, 0.52, 0.96 }
	elseif kind == "umbra" then color = { 0.93, 0.2, 0.76 } end
	local base = { x = screen_x, y = screen_y, color = color, elapsed = 0, duration = 0.6, particles = {} }
	for _ = 1, 4 do
		base.particles[#base.particles + 1] = {
			vx = (math.random() * 2 - 1) * 60,
			vy = (math.random() * 2 - 1) * 60,
			size = 4 + math.random() * 4,
		}
	end
	self.death_particles[#self.death_particles + 1] = base
end

function FX:get_bob_offset(is_moving)
	if not self.settings.footstep_bob or not is_moving then return 0 end
	return math.sin(self.bob_phase) * self.bob_amplitude
end

function FX:get_sway_offset(is_moving)
	if not self.settings.footstep_bob or not is_moving then return 0 end
	return math.cos(self.bob_phase * 0.5) * self.bob_amplitude * 0.6
end

function FX:apply_camera(camera, is_moving, momentum)
	camera.x = camera.x + self.shake_offset_x * 0.03
	camera.y = camera.y + self.shake_offset_y * 0.03
	camera.height = camera.height + self:get_bob_offset(is_moving)
	local sway = self:get_sway_offset(is_moving)
	local right_x = -math.sin(camera.angle)
	local right_y = math.cos(camera.angle)
	camera.x = camera.x + right_x * sway
	camera.y = camera.y + right_y * sway
	if momentum then
		if momentum:is_airborne() then -- jump arc camera
			local t = momentum.air_time / JUMP_ARC_TIME
			camera.height = camera.height + math.sin(t * math.pi) * 0.12
		end
		if momentum.chain_bonus > 1.05 then -- bhop chain increases bob
			self.bob_amplitude = 0.012 + (momentum.chain_bonus - 1.0) * 0.02
		else
			self.bob_amplitude = 0.012
		end
		camera.roll = 0
		if momentum:is_wall_running() then -- wall run tilt
			local tilt = momentum.wall_run_side == "left" and -0.08 or 0.08
			camera.roll = tilt
		end
	end
end

function FX:draw_particles()
	if not love then return end
	local lg = love.graphics
	for _, flash in ipairs(self.kill_flashes) do
		local alpha = util.clamp(flash.ttl / 0.15, 0, 0.6)
		lg.setColor(1, 1, 1, alpha)
		lg.circle("fill", flash.x, flash.y, flash.radius * (1 - flash.ttl / 0.15))
	end
	for _, group in ipairs(self.death_particles) do
		local t = group.elapsed / group.duration
		local alpha = util.clamp(1 - t, 0, 0.8)
		local scale = util.clamp(1 - t * 0.6, 0.2, 1)
		lg.setColor(group.color[1], group.color[2], group.color[3], alpha)
		lg.rectangle("fill", group.x - 6 * scale, group.y - 8 * scale, 12 * scale, 16 * scale)
		for _, p in ipairs(group.particles) do
			local px = group.x + p.vx * group.elapsed
			local py = group.y + p.vy * group.elapsed
			local s = p.size * (1 - t)
			lg.setColor(group.color[1], group.color[2], group.color[3], alpha * 0.6)
			lg.rectangle("fill", px - s * 0.5, py - s * 0.5, s, s)
		end
	end
end

function FX:draw_low_charge_pulse(light_charge, max_charge)
	if not self.settings.pulse_light then return end
	if not love then return end
	if light_charge >= 20 or max_charge <= 0 then return end
	local lg = love.graphics
	local width, height = lg.getDimensions()
	local pulse = math.sin(self.low_charge_phase) * 0.5 + 0.5
	local alpha = util.clamp((1 - light_charge / 20) * 0.18 * pulse, 0, 0.18)
	lg.setColor(0.9, 0.6, 0.1, alpha)
	lg.rectangle("fill", 0, 0, width, height)
end

return FX
