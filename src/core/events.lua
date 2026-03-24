local Events = {}
Events.__index = Events

function Events.new()
	return setmetatable({ listeners = {} }, Events)
end

function Events:on(name, callback)
	if not self.listeners[name] then
		self.listeners[name] = {}
	end
	local list = self.listeners[name]
	list[#list + 1] = callback
	return function() -- unsubscribe handle
		for i, cb in ipairs(list) do
			if cb == callback then
				table.remove(list, i)
				return
			end
		end
	end
end

function Events:emit(name, payload)
	local list = self.listeners[name]
	if not list then return end
	for _, callback in ipairs(list) do
		callback(payload)
	end
end

function Events:clear()
	self.listeners = {}
end

return Events
