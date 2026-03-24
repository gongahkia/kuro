local Meta = {}
Meta.__index = Meta

local unlock_defs = {
	{ id = "mutator_ironman", label = "Ironman", desc = "1 HP, double damage", condition = function(m) return m.total_victories >= 3 end },
	{ id = "mutator_blacklight", label = "Blacklight", desc = "See enemies through walls, -2 HP", condition = function(m) return m.total_runs >= 5 end },
	{ id = "loadout_scout", label = "Scout", desc = "Start with +2 flares", condition = function(m) return m.damageless_floor2 end },
	{ id = "light_color_red", label = "Red Flame", desc = "Cosmetic red light", condition = function(m) return m.total_burns >= 50 end },
	{ id = "light_color_blue", label = "Blue Flame", desc = "Cosmetic blue light", condition = function(m) return m.total_burns >= 100 end },
}

function Meta.new(settings)
	local data = settings and settings.meta_unlocks or {}
	return setmetatable({
		unlocks = data,
		total_runs = settings and settings.total_runs or 0,
		total_victories = settings and settings.total_victories or 0,
		total_burns = settings and settings.total_burns or 0,
		damageless_floor2 = settings and settings.damageless_floor2 or false,
	}, Meta)
end

function Meta:record_run(summary, _codex)
	self.total_runs = self.total_runs + 1
	if summary then
		if summary.stats then
			self.total_burns = self.total_burns + (summary.stats.enemies_burned or 0)
			if summary.stats.floors_cleared >= 2 and summary.stats.damage_taken == 0 then
				self.damageless_floor2 = true
			end
		end
		if summary.difficulty == "victory" or (summary.stats and summary.stats.floors_cleared >= 3) then
			self.total_victories = self.total_victories + 1
		end
	end
	self:check_unlocks()
end

function Meta:check_unlocks()
	for _, def in ipairs(unlock_defs) do
		if not self.unlocks[def.id] and def.condition(self) then
			self.unlocks[def.id] = true
		end
	end
end

function Meta:is_unlocked(id)
	return self.unlocks[id] == true
end

function Meta:get_available_mutators()
	local base = { "embers", "echoes", "onslaught" }
	for _, def in ipairs(unlock_defs) do
		if def.id:find("^mutator_") and self.unlocks[def.id] then
			base[#base + 1] = def.id:sub(9) -- strip "mutator_" prefix
		end
	end
	return base
end

function Meta:get_all_unlocks()
	local result = {}
	for _, def in ipairs(unlock_defs) do
		result[#result + 1] = {
			id = def.id,
			label = def.label,
			desc = def.desc,
			unlocked = self.unlocks[def.id] == true,
		}
	end
	return result
end

function Meta:save(settings)
	settings.meta_unlocks = self.unlocks
	settings.total_runs = self.total_runs
	settings.total_victories = self.total_victories
	settings.total_burns = self.total_burns
	settings.damageless_floor2 = self.damageless_floor2
end

return Meta
