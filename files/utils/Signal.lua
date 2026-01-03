--- Lua-side duplication of the API of events on Roblox objects.
-- Signals are needed for to ensure that for local events objects are passed by
-- reference rather than by value where possible, as the BindableEvent objects
-- always pass signal arguments by value, meaning tables will be deep copied.
-- Roblox's deep copy method parses to a non-lua table compatable format.
-- @classmod Signal

local Signal = {}
Signal.__index = Signal
Signal.ClassName = "Signal"

--- Constructs a new signal.
-- @constructor Signal.new()
-- @treturn Signal
function Signal.new()
	local self = setmetatable({}, Signal)

	self._bindableEvent = Instance.new("BindableEvent")
	self._argData = nil
	self._argCount = nil -- Prevent edge case of :Fire("A", nil) --> "A" instead of "A", nil

	return self
end

function Signal.isSignal(object)
	return typeof(object) == 'table' and getmetatable(object) == Signal;
end;

--- Fire the event with the given arguments. All handlers will be invoked. Handlers follow
-- Roblox signal conventions.
-- @param ... Variable arguments to pass to handler
-- @treturn nil
function Signal:Fire(...)
    local args = {...}
    local count = select("#", ...)
    
    -- Instead of setting and clearing self._argData, 
    -- we trigger the event which will have access to these local variables
    self._argCount = count
    self._argData = args
    self._bindableEvent:Fire()
end

function Signal:Connect(handler)
    if not self._bindableEvent then return error("Signal has been destroyed") end

    return self._bindableEvent.Event:Connect(function()
        -- Capture the current state of the signal's data
        local data = self._argData
        local count = self._argCount
        if data then
            handler(unpack(data, 1, count))
        end
    end)
end
--- Wait for fire to be called, and return the arguments it was given.
-- @treturn ... Variable arguments from connection
function Signal:Wait()
	self._bindableEvent.Event:Wait()
	assert(self._argData, "Missing arg data, likely due to :TweenSize/Position corrupting threadrefs.")
	return unpack(self._argData, 1, self._argCount)
end

--- Disconnects all connected events to the signal. Voids the signal as unusable.
-- @treturn nil
function Signal:Destroy()
	if self._bindableEvent then
		self._bindableEvent:Destroy()
		self._bindableEvent = nil
	end

	self._argData = nil
	self._argCount = nil
end

return Signal
