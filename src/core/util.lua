local util = {}

function util.clamp(value, low, high)
	if value < low then
		return low
	end
	if value > high then
		return high
	end
	return value
end

function util.lerp(a, b, t)
	return a + (b - a) * t
end

function util.approach(value, target, delta)
	if value < target then
		return math.min(value + delta, target)
	end
	if value > target then
		return math.max(value - delta, target)
	end
	return target
end

function util.round(value)
	if value >= 0 then
		return math.floor(value + 0.5)
	end
	return math.ceil(value - 0.5)
end

function util.sign(value)
	if value > 0 then
		return 1
	end
	if value < 0 then
		return -1
	end
	return 0
end

function util.wrap_angle(value)
	local tau = math.pi * 2
	value = value % tau
	if value < 0 then
		value = value + tau
	end
	return value
end

function util.distance(ax, ay, bx, by)
	local dx = bx - ax
	local dy = by - ay
	return math.sqrt(dx * dx + dy * dy)
end

function util.normalize(x, y)
	local length = math.sqrt(x * x + y * y)
	if length == 0 then
		return 0, 0, 0
	end
	return x / length, y / length, length
end

function util.deepcopy(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local copy = {}
	seen[value] = copy
	for key, inner in pairs(value) do
		copy[util.deepcopy(key, seen)] = util.deepcopy(inner, seen)
	end
	return copy
end

function util.shallow_copy(value)
	local copy = {}
	for key, inner in pairs(value) do
		copy[key] = inner
	end
	return copy
end

function util.append_all(target, values)
	for index = 1, #values do
		target[#target + 1] = values[index]
	end
end

return util
