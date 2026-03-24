local LoreData = require("src.data.lore")

local Codex = {}
Codex.__index = Codex

function Codex.new()
	return setmetatable({
		found_fragments = {},
		unlocked_entries = {},
		bestiary = {},
	}, Codex)
end

function Codex:discover_fragment(id)
	if self.found_fragments[id] then return false end
	self.found_fragments[id] = true
	self:check_entries()
	return true
end

function Codex:record_enemy(kind)
	self.bestiary[kind] = (self.bestiary[kind] or 0) + 1
end

function Codex:check_entries()
	for _, entry in ipairs(LoreData.codex_entries) do
		if not self.unlocked_entries[entry.id] then
			local all_found = true
			for _, frag_id in ipairs(entry.requires_fragments) do
				if not self.found_fragments[frag_id] then
					all_found = false
					break
				end
			end
			if all_found then
				self.unlocked_entries[entry.id] = true
			end
		end
	end
end

function Codex:is_fragment_found(id)
	return self.found_fragments[id] == true
end

function Codex:get_unlocked_entries()
	local result = {}
	for _, entry in ipairs(LoreData.codex_entries) do
		if self.unlocked_entries[entry.id] then
			result[#result + 1] = entry
		end
	end
	return result
end

function Codex:serialize()
	return {
		found_fragments = self.found_fragments,
		unlocked_entries = self.unlocked_entries,
		bestiary = self.bestiary,
	}
end

function Codex:deserialize(data)
	if not data then return end
	self.found_fragments = data.found_fragments or {}
	self.unlocked_entries = data.unlocked_entries or {}
	self.bestiary = data.bestiary or {}
	self:check_entries()
end

return Codex
