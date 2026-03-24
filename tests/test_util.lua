local util = require("src.core.util")

return {
	["wrap angle stays positive"] = function()
		local wrapped = util.wrap_angle(-math.pi / 2)
		assert(wrapped > 0, "angle should be wrapped into positive range")
	end,

	["deepcopy duplicates nested tables"] = function()
		local source = { a = 1, b = { c = 2 } }
		local copy = util.deepcopy(source)
		copy.b.c = 9
		assert(source.b.c == 2, "nested mutation should not leak back")
	end,
}
