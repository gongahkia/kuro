local Relics = {}
Relics.__index = Relics

function Relics.new()
	return setmetatable({
		held = {},
		max_slots = 3,
	}, Relics)
end

function Relics:add(relic_def)
	if #self.held >= self.max_slots then return false end
	self.held[#self.held + 1] = relic_def
	return true
end

function Relics:has_effect(effect_name)
	for _, relic in ipairs(self.held) do
		if relic.effect == effect_name then return relic end
	end
	return nil
end

function Relics:get_value(effect_name, default)
	for _, relic in ipairs(self.held) do
		if relic.effect == effect_name then return relic.value end
	end
	return default
end

function Relics:apply_stat_modifiers(player)
	for _, relic in ipairs(self.held) do
		if relic.effect == "max_health_add" then
			player.max_health = player.max_health + relic.value
			player.health = math.min(player.health + relic.value, player.max_health)
		elseif relic.effect == "move_speed_mult" then
			player.move_speed = player.move_speed * relic.value
		end
	end
end

function Relics:list()
	return self.held
end

function Relics:count()
	return #self.held
end

return Relics
