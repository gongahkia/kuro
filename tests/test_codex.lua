local Codex = require("src.game.codex")

return {
	["codex discover fragment marks found"] = function()
		local c = Codex.new()
		assert(c:discover_fragment(1) == true, "expected true on first discover")
		assert(c:is_fragment_found(1), "expected fragment found")
		assert(c:discover_fragment(1) == false, "expected false on duplicate")
	end,
	["codex entry unlocks when prerequisites met"] = function()
		local c = Codex.new()
		c:discover_fragment(1)
		c:discover_fragment(5)
		local entries = c:get_unlocked_entries()
		local found = false
		for _, e in ipairs(entries) do
			if e.id == "origin" then found = true end
		end
		assert(found, "expected 'origin' entry unlocked with fragments 1+5")
	end,
	["codex entry stays locked without prerequisites"] = function()
		local c = Codex.new()
		c:discover_fragment(1)
		local entries = c:get_unlocked_entries()
		for _, e in ipairs(entries) do
			assert(e.id ~= "origin", "origin should not unlock with only fragment 1")
		end
	end,
	["codex record enemy tracks kills"] = function()
		local c = Codex.new()
		c:record_enemy("stalker")
		c:record_enemy("stalker")
		c:record_enemy("leech")
		assert(c.bestiary.stalker == 2, "expected 2 stalker kills")
		assert(c.bestiary.leech == 1, "expected 1 leech kill")
	end,
	["codex serialize roundtrip"] = function()
		local c = Codex.new()
		c:discover_fragment(3)
		c:record_enemy("rusher")
		local data = c:serialize()
		local c2 = Codex.new()
		c2:deserialize(data)
		assert(c2:is_fragment_found(3), "expected fragment 3 preserved")
		assert(c2.bestiary.rusher == 1, "expected rusher kill preserved")
	end,
}
