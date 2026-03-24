local Events = require("src.core.events")

return {
	["events emit fires registered callback"] = function()
		local bus = Events.new()
		local received = nil
		bus:on("test", function(payload) received = payload end)
		bus:emit("test", { value = 42 })
		assert(received and received.value == 42, "expected payload")
	end,
	["events emit with no listeners is safe"] = function()
		local bus = Events.new()
		bus:emit("nonexistent", {})
	end,
	["events on returns unsubscribe handle"] = function()
		local bus = Events.new()
		local count = 0
		local unsub = bus:on("test", function() count = count + 1 end)
		bus:emit("test", {})
		assert(count == 1, "expected 1 call")
		unsub()
		bus:emit("test", {})
		assert(count == 1, "expected no further calls after unsub")
	end,
	["events clear removes all listeners"] = function()
		local bus = Events.new()
		local count = 0
		bus:on("a", function() count = count + 1 end)
		bus:on("b", function() count = count + 1 end)
		bus:clear()
		bus:emit("a", {})
		bus:emit("b", {})
		assert(count == 0, "expected 0 calls after clear")
	end,
	["events multiple listeners on same event"] = function()
		local bus = Events.new()
		local a, b = 0, 0
		bus:on("test", function() a = a + 1 end)
		bus:on("test", function() b = b + 1 end)
		bus:emit("test", {})
		assert(a == 1 and b == 1, "expected both called")
	end,
}
