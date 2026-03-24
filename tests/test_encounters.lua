local Encounters = require("src.game.encounters")
local RNG = require("src.core.rng")

return {
	["encounters build_pool filters by floor"] = function()
		local pool = Encounters.build_pool(1, true)
		for _, id in ipairs(pool) do
			assert(id ~= "gauntlet", "gauntlet should not appear on floor 1")
		end
		local pool2 = Encounters.build_pool(2, true)
		local found = false
		for _, id in ipairs(pool2) do
			if id == "gauntlet" then found = true end
		end
		assert(found, "gauntlet should appear on floor 2")
	end,
	["encounters pick returns safe options without threat"] = function()
		local rng = RNG.new(42)
		local safe = { ["torch-cache"] = true, shrine = true, revelation = true, lore = true, riddle = true, gamble_shrine = true }
		for _ = 1, 20 do
			local picked = Encounters.pick(rng, 1, false)
			assert(safe[picked], "expected safe encounter, got " .. tostring(picked))
		end
	end,
	["encounters all handlers are callable"] = function()
		for id, handler in pairs(Encounters.handlers) do
			assert(type(handler) == "function", "handler for " .. id .. " should be a function")
		end
	end,
}
