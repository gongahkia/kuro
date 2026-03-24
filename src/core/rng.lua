local bit = require("bit")
local band, bxor, lshift, rshift = bit.band, bit.bxor, bit.lshift, bit.rshift
local RNG = {}
RNG.__index = RNG

local function sanitize_seed(seed)
	seed = math.floor(tonumber(seed) or 1)
	seed = band(seed, 0xffffffff)
	if seed == 0 then
		seed = 0x6d2b79f5
	end
	return seed
end

function RNG.new(seed)
	return setmetatable({
		state = sanitize_seed(seed),
	}, RNG)
end

function RNG:next_uint()
	local x = self.state
	x = bxor(x, band(lshift(x, 13), 0xffffffff))
	x = bxor(x, rshift(x, 17))
	x = bxor(x, band(lshift(x, 5), 0xffffffff))
	self.state = sanitize_seed(x)
	return self.state
end

function RNG:float()
	return self:next_uint() / 0xffffffff
end

function RNG:int(low, high)
	if high == nil then
		high = low
		low = 1
	end
	if high < low then
		low, high = high, low
	end
	local span = high - low + 1
	return low + (self:next_uint() % span)
end

function RNG:chance(probability)
	return self:float() <= probability
end

function RNG:choice(values)
	assert(#values > 0, "choice requires values")
	return values[self:int(1, #values)]
end

function RNG:shuffle(values)
	for index = #values, 2, -1 do
		local swap_index = self:int(1, index)
		values[index], values[swap_index] = values[swap_index], values[index]
	end
	return values
end

return RNG
