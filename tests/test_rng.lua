local RNG = require("src.core.rng")

return {
	["rng is deterministic for the same seed"] = function()
		local left = RNG.new(77)
		local right = RNG.new(77)
		for _ = 1, 10 do
			assert(left:next_uint() == right:next_uint(), "expected matching sequence")
		end
	end,

	["rng choice stays within bounds"] = function()
		local rng = RNG.new(5)
		local values = { "a", "b", "c" }
		for _ = 1, 20 do
			local picked = rng:choice(values)
			assert(picked == "a" or picked == "b" or picked == "c", "unexpected choice")
		end
	end,
}
