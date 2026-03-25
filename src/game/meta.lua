local Meta = {}
Meta.__index = Meta

local unlock_defs = {
	{ id = "mutator_ironman", group = "mutator", value = "ironman", label = "Ironman", desc = "1 HP, double incoming damage.", condition = function(m) return m.total_victories >= 3 end },
	{ id = "mutator_blacklight", group = "mutator", value = "blacklight", label = "Blacklight", desc = "See enemies through walls, lose 2 max HP.", condition = function(m) return m.total_runs >= 5 end },
	{ id = "loadout_scout", group = "loadout", value = "scout", label = "Scout", desc = "Start each run with 2 extra flares.", condition = function(m) return m.damageless_floor2 end },
	{ id = "light_color_red", group = "flame", value = "red", label = "Red Flame", desc = "Cosmetic ember-red flame color.", condition = function(m) return m.total_burns >= 50 end },
	{ id = "light_color_blue", group = "flame", value = "blue", label = "Blue Flame", desc = "Cosmetic hollow-blue flame color.", condition = function(m) return m.total_burns >= 100 end },
}

local base_mutators = { "embers", "echoes", "onslaught" }
local base_loadouts = {
	{ id = "default", label = "Descender", desc = "Standard descent loadout." },
}
local base_flames = {
	{ id = "amber", label = "Amber Flame", desc = "Default warm survival flame." },
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
	local base = {}
	for _, id in ipairs(base_mutators) do
		base[#base + 1] = id
	end
	for _, def in ipairs(unlock_defs) do
		if def.group == "mutator" and self.unlocks[def.id] then
			base[#base + 1] = def.value
		end
	end
	return base
end

function Meta:get_available_loadouts()
	local available = {}
	for _, def in ipairs(base_loadouts) do
		available[#available + 1] = {
			id = def.id,
			label = def.label,
			desc = def.desc,
			unlocked = true,
		}
	end
	for _, def in ipairs(unlock_defs) do
		if def.group == "loadout" and self.unlocks[def.id] then
			available[#available + 1] = {
				id = def.value,
				label = def.label,
				desc = def.desc,
				unlocked = true,
			}
		end
	end
	return available
end

function Meta:get_available_flames()
	local available = {}
	for _, def in ipairs(base_flames) do
		available[#available + 1] = {
			id = def.id,
			label = def.label,
			desc = def.desc,
			unlocked = true,
		}
	end
	for _, def in ipairs(unlock_defs) do
		if def.group == "flame" and self.unlocks[def.id] then
			available[#available + 1] = {
				id = def.value,
				label = def.label,
				desc = def.desc,
				unlocked = true,
			}
		end
	end
	return available
end

function Meta:get_all_unlocks()
	local result = {}
	for _, def in ipairs(unlock_defs) do
		result[#result + 1] = {
			id = def.id,
			group = def.group,
			value = def.value,
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
