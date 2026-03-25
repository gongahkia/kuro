local Momentum = require("src.game.momentum")

local function make_player(angle)
	return { x = 5, y = 5, angle = angle or 0, move_speed = 2.6, strafe_speed = 2.35, radius = 0.18 }
end

local function make_input(overrides)
	local inp = { move = 0, strafe = 0, turn = 0, crouch = false, move_speed = 2.6, strafe_speed = 2.35 }
	if overrides then
		for k, v in pairs(overrides) do inp[k] = v end
	end
	return inp
end

return {
	["momentum starts at zero speed"] = function()
		local m = Momentum.new()
		assert(m:get_speed() == 0, "expected zero initial speed")
	end,
	["momentum decays to zero with no input"] = function()
		local m = Momentum.new()
		m.vx, m.vy = 2.0, 1.0
		for _ = 1, 60 do
			m:update(1/60, make_input(), make_player(), nil)
		end
		assert(m:get_speed() < 0.01, "expected near-zero after friction decay, got " .. m:get_speed())
	end,
	["momentum matches base speed with forward input"] = function()
		local m = Momentum.new()
		local p = make_player(0)
		for _ = 1, 30 do
			m:update(1/60, make_input({ move = 1 }), p, nil)
		end
		local speed = m:get_speed()
		assert(speed > 2.0 and speed < 3.0, "expected ~2.6 speed, got " .. speed)
	end,
	["momentum ground caps diagonal speed"] = function()
		local m = Momentum.new()
		local p = make_player(0)
		for _ = 1, 30 do
			m:update(1/60, make_input({ move = 1, strafe = 1 }), p, nil)
		end
		local speed = m:get_speed()
		assert(speed <= 2.7, "expected capped diagonal speed, got " .. speed)
	end,
	["momentum technique reports none on ground"] = function()
		local m = Momentum.new()
		m:update(1/60, make_input(), make_player(), nil)
		assert(m:get_technique() == "none", "expected none technique")
	end,
	["momentum slide activates at speed"] = function()
		local m = Momentum.new()
		local p = make_player(0)
		for _ = 1, 30 do
			m:update(1/60, make_input({ move = 1 }), p, nil)
		end
		m:update(1/60, make_input({ move = 1, crouch = true }), p, nil)
		assert(m:is_sliding(), "expected slide to activate")
		assert(m.stats.slides == 1, "expected 1 slide counted")
	end,
	["momentum slide does not activate when slow"] = function()
		local m = Momentum.new()
		m:update(1/60, make_input({ crouch = true }), make_player(), nil)
		assert(not m:is_sliding(), "expected no slide when stationary")
	end,
	["momentum jump makes airborne"] = function()
		local m = Momentum.new()
		m:request_jump()
		m:update(1/60, make_input(), make_player(), nil)
		assert(m:is_airborne(), "expected airborne after jump")
	end,
	["momentum chain bonus stacks from notify_tech"] = function()
		local m = Momentum.new()
		m:notify_tech("bhop")
		assert(m.chain_bonus > 1.0, "expected chain bonus after bhop")
	end,
	["momentum chain decays over time"] = function()
		local m = Momentum.new()
		m:notify_tech("bhop")
		for _ = 1, 120 do
			m:update(1/60, make_input(), make_player(), nil)
		end
		assert(m.chain_bonus == 1.0, "expected chain to decay")
	end,
	["momentum reset clears state"] = function()
		local m = Momentum.new()
		m.vx, m.vy = 5, 5
		m.chain_bonus = 2.0
		m:reset()
		assert(m:get_speed() == 0, "expected zero after reset")
		assert(m.chain_bonus == 1.0, "expected chain reset")
	end,
	["momentum diagonal uncapped with chain bonus"] = function()
		local m = Momentum.new()
		local p = make_player(0)
		m:notify_tech("bhop") -- activate chain
		for _ = 1, 30 do
			m:update(1/60, make_input({ move = 1, strafe = 1 }), p, nil)
		end
		local speed = m:get_speed()
		assert(speed > 2.7, "expected uncapped diagonal with chain, got " .. speed)
	end,
	["momentum air strafe adds lateral velocity"] = function()
		local m = Momentum.new()
		local p = make_player(0) -- facing east
		-- get up to speed and jump
		for _ = 1, 30 do
			m:update(1/60, make_input({ move = 1 }), p, nil)
		end
		m:request_jump()
		m:update(1/60, make_input({ move = 1 }), p, nil)
		assert(m:is_airborne(), "expected airborne")
		local before_vy = m.vy
		-- apply turn input during air (should add lateral velocity)
		for _ = 1, 10 do
			m:update(1/60, make_input({ turn = 1 }), p, nil)
		end
		assert(math.abs(m.vy - before_vy) > 0.01, "expected lateral velocity change from air strafe")
	end,
}
