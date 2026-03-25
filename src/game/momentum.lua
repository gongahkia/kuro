local util = require("src.core.util")

local Momentum = {}
Momentum.__index = Momentum

local GROUND_FRICTION = 12.0
local AIR_FRICTION = 0.3
local SLIDE_FRICTION = 1.2
local WALL_RUN_FRICTION = 0.0
local SLIDE_DURATION = 0.7
local SLIDE_BURST = 1.15
local SLIDE_MIN_SPEED = 2.0
local JUMP_AIR_TIME = 0.4
local BHOP_WINDOW = 0.1
local BHOP_BONUS = 0.08
local MAX_CHAIN = 2.5
local CHAIN_DECAY_TIME = 1.5
local AIR_STRAFE_ACCEL = 6.0
local WALL_RUN_MAX_TIME = 1.2
local WALL_RUN_SPEED_MULT = 1.1
local WALL_DETECT_DIST = 0.23 -- radius + 0.05
local WALL_ANGLE_THRESHOLD = math.rad(15)
local WALL_KICK_SPEED = 3.0
local PROPULSION_ACCEL = 4.0
local BASE_SPEED_CAP = 2.6 -- matches move_speed

function Momentum.new()
	return setmetatable({
		vx = 0,
		vy = 0,
		speed = 0,
		grounded = true,
		slide_time = 0,
		sliding = false,
		air_time = 0,
		airborne = false,
		jump_requested = false,
		bhop_pending = false,
		wall_run_time = 0,
		wall_run_side = nil,
		wall_running = false,
		wall_normal_x = 0,
		wall_normal_y = 0,
		chain_bonus = 1.0,
		chain_timer = 0,
		technique = "none", -- none/slide/air/wall/chain
		propulsion_force = 0,
		stats = {
			slides = 0,
			bhops = 0,
			wall_runs = 0,
			chains = 0,
			propulsions = 0,
		},
	}, Momentum)
end

function Momentum:get_speed()
	return self.speed
end

function Momentum:is_sliding()
	return self.sliding
end

function Momentum:is_airborne()
	return self.airborne
end

function Momentum:is_wall_running()
	return self.wall_running
end

function Momentum:get_technique()
	if self.wall_running then return "WALL" end
	if self.sliding then return "SLIDE" end
	if self.airborne then return "AIR" end
	if self.chain_bonus > 1.05 then return string.format("CHAIN x%.1f", self.chain_bonus) end
	return "none"
end

function Momentum:notify_tech(tech_name)
	local bonuses = {
		slide_jump = 1.15,
		bhop_wall_run = 1.2,
		wall_kick_bhop = 1.3,
		burn_dash_bhop = 1.25,
		bhop = 1.0 + BHOP_BONUS,
	}
	local bonus = bonuses[tech_name]
	if bonus then
		self.chain_bonus = math.min(MAX_CHAIN, self.chain_bonus * bonus)
		self.chain_timer = CHAIN_DECAY_TIME
		if self.chain_bonus > 1.1 then
			self.stats.chains = self.stats.chains + 1
		end
	end
end

function Momentum:request_jump()
	self.jump_requested = true
end

function Momentum:set_propulsion(force)
	self.propulsion_force = force
end

function Momentum:update(dt, input, player, world_query)
	local move = input.move or 0 -- -1/0/1
	local strafe = input.strafe or 0
	local crouch = input.crouch or false
	local move_speed = input.move_speed or player.move_speed
	local strafe_speed = input.strafe_speed or player.strafe_speed
	local forward_x = math.cos(player.angle)
	local forward_y = math.sin(player.angle)
	local right_x = -math.sin(player.angle)
	local right_y = math.cos(player.angle)
	self:_update_chain(dt)
	self:_update_slide(dt, crouch, move, strafe)
	self:_update_air(dt)
	self:_update_wall_run(dt, player, forward_x, forward_y, world_query)
	local friction = self:_get_friction()
	local accel_x, accel_y = 0, 0
	if self.sliding then
		-- no input acceleration during slide, just friction
	elseif self.wall_running then
		-- wall run: move along wall direction only
		local wall_dx = -self.wall_normal_y
		local wall_dy = self.wall_normal_x
		if forward_x * wall_dx + forward_y * wall_dy < 0 then
			wall_dx, wall_dy = -wall_dx, -wall_dy
		end
		accel_x = wall_dx * move_speed * WALL_RUN_SPEED_MULT
		accel_y = wall_dy * move_speed * WALL_RUN_SPEED_MULT
		self.vx = accel_x
		self.vy = accel_y
		accel_x, accel_y = 0, 0
	elseif self.airborne then
		-- air: reduced forward control + air strafe from turn
		accel_x = (forward_x * move * move_speed + right_x * strafe * strafe_speed) * 0.3
		accel_y = (forward_y * move * move_speed + right_y * strafe * strafe_speed) * 0.3
		-- air strafe from A/D turn adds lateral velocity
		local turn = input.turn or 0
		if turn ~= 0 then
			accel_x = accel_x + right_x * turn * AIR_STRAFE_ACCEL
			accel_y = accel_y + right_y * turn * AIR_STRAFE_ACCEL
		end
	else
		-- ground: direct input → velocity (high friction converges fast)
		accel_x = forward_x * move * move_speed + right_x * strafe * strafe_speed
		accel_y = forward_y * move * move_speed + right_y * strafe * strafe_speed
	end
	-- propulsion (backward fire)
	if self.propulsion_force > 0 then
		accel_x = accel_x + forward_x * self.propulsion_force
		accel_y = accel_y + forward_y * self.propulsion_force
		self.propulsion_force = 0
	end
	-- apply acceleration
	self.vx = self.vx + accel_x * dt
	self.vy = self.vy + accel_y * dt
	-- apply friction
	local decay = math.max(0, 1 - friction * dt)
	self.vx = self.vx * decay
	self.vy = self.vy * decay
	-- apply chain bonus
	local effective_vx = self.vx * self.chain_bonus
	local effective_vy = self.vy * self.chain_bonus
	-- normalize if grounded and no chain (matches original capped behavior)
	if self.grounded and not self.sliding and self.chain_bonus <= 1.0 then
		local nx, ny, length = util.normalize(effective_vx, effective_vy)
		if length > 0 then
			local cap = math.max(move_speed, strafe_speed)
			if length > cap then
				effective_vx = nx * cap
				effective_vy = ny * cap
			end
		end
	end
	self.speed = math.sqrt(effective_vx * effective_vx + effective_vy * effective_vy)
	self.technique = self:get_technique()
	return effective_vx, effective_vy
end

function Momentum:_update_chain(dt)
	if self.chain_timer > 0 then
		self.chain_timer = self.chain_timer - dt
		if self.chain_timer <= 0 then
			self.chain_bonus = 1.0
			self.chain_timer = 0
		end
	end
end

function Momentum:_update_slide(dt, crouch, move, strafe)
	if self.sliding then
		self.slide_time = self.slide_time - dt
		if self.slide_time <= 0 or self.jump_requested or not crouch then
			local was_sliding = true
			self.sliding = false
			self.slide_time = 0
			if self.jump_requested and was_sliding then
				self:notify_tech("slide_jump")
			end
		end
		return
	end
	if crouch and self.grounded and not self.airborne and self.speed >= SLIDE_MIN_SPEED then
		self.sliding = true
		self.slide_time = SLIDE_DURATION
		local nx, ny, length = util.normalize(self.vx, self.vy)
		if length > 0 then
			self.vx = nx * length * SLIDE_BURST
			self.vy = ny * length * SLIDE_BURST
		end
		self.stats.slides = self.stats.slides + 1
	end
end

function Momentum:_update_air(dt)
	if self.airborne then
		self.air_time = self.air_time - dt
		if self.air_time <= 0 then
			-- landing
			self.airborne = false
			self.grounded = true
			self.air_time = 0
			if self.jump_requested then
				-- bhop: jump pressed near landing
				local time_to_land = self.air_time + dt -- how close to landing
				if time_to_land <= BHOP_WINDOW then
					self:_do_jump()
					self:notify_tech("bhop")
					self.stats.bhops = self.stats.bhops + 1
				end
			end
			if self.wall_running then
				self.wall_running = false
				self.wall_run_time = 0
			end
		end
	end
	if self.jump_requested and not self.airborne then
		self:_do_jump()
		self.jump_requested = false
		return
	end
	self.jump_requested = false
end

function Momentum:_do_jump()
	self.airborne = true
	self.grounded = false
	self.air_time = JUMP_AIR_TIME
	if self.sliding then
		self.sliding = false
		self.slide_time = 0
		self:notify_tech("slide_jump")
	end
end

function Momentum:_update_wall_run(dt, player, forward_x, forward_y, world_query)
	if not self.airborne or not world_query then
		if self.wall_running then
			self.wall_running = false
			self.wall_run_time = 0
		end
		return
	end
	if self.wall_running then
		self.wall_run_time = self.wall_run_time - dt
		if self.wall_run_time <= 0 or self.jump_requested then
			-- wall kick
			local kick_x = self.wall_normal_x * WALL_KICK_SPEED
			local kick_y = self.wall_normal_y * WALL_KICK_SPEED
			self.vx = self.vx + kick_x
			self.vy = self.vy + kick_y
			self.wall_running = false
			self.wall_run_time = 0
			if self.jump_requested then
				self:_do_jump()
				self:notify_tech("wall_kick_bhop")
			end
		end
		return
	end
	-- detect wall for new wall run
	if self.speed < SLIDE_MIN_SPEED then return end
	local wall_info = world_query(player.x, player.y, forward_x, forward_y)
	if not wall_info then return end
	-- check angle: player must be moving roughly parallel to wall
	local move_nx, move_ny = util.normalize(self.vx, self.vy)
	local wall_dx = -wall_info.normal_y
	local wall_dy = wall_info.normal_x
	local dot = math.abs(move_nx * wall_dx + move_ny * wall_dy)
	if dot < math.cos(WALL_ANGLE_THRESHOLD) then return end
	self.wall_running = true
	self.wall_run_time = WALL_RUN_MAX_TIME
	self.wall_normal_x = wall_info.normal_x
	self.wall_normal_y = wall_info.normal_y
	self.wall_run_side = (wall_info.normal_x * right_x + wall_info.normal_y * right_y) > 0 and "right" or "left"
	self.stats.wall_runs = self.stats.wall_runs + 1
	local right_x = -math.sin(player.angle)
	local right_y = math.cos(player.angle)
	self.wall_run_side = (wall_info.normal_x * right_x + wall_info.normal_y * right_y) > 0 and "right" or "left"
end

function Momentum:_get_friction()
	if self.wall_running then return WALL_RUN_FRICTION end
	if self.sliding then return SLIDE_FRICTION end
	if self.airborne then return AIR_FRICTION end
	return GROUND_FRICTION
end

function Momentum:reset()
	self.vx = 0
	self.vy = 0
	self.speed = 0
	self.grounded = true
	self.sliding = false
	self.slide_time = 0
	self.airborne = false
	self.air_time = 0
	self.wall_running = false
	self.wall_run_time = 0
	self.wall_run_side = nil
	self.chain_bonus = 1.0
	self.chain_timer = 0
	self.technique = "none"
	self.propulsion_force = 0
end

return Momentum
