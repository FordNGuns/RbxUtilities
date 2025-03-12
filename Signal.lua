-- -----------------------------------------------------------------------------
--                        Signal Implementation for Luau                      --
-- A lightweight Signal implementation for event handling in Luau. This       --
-- module provides a simple yet powerful way to implement the Observer        --
-- pattern, allowing for event-driven programming. It supports connection     --
-- management, safe disconnection, and multi-threaded event firing.           --
--                                                                            --
-- License:                                                                   --
--   Licensed under the MIT license.                                          --
--                                                                            --
-- Authors:                                                                   --
--   FordNGuns - March 11th 2025 - Created the file                           --
-- -----------------------------------------------------------------------------

--[=[
    @class Signal

    Basic usage:
    ```lua
    local Signal = require(path.to.Signal)

    -- Create a new signal
    local onDataReceived = Signal.new()

    -- Connect to the signal
    local connection = onDataReceived:Connect(function(data)
        print("Received data:", data)
    end)

    -- Fire the signal
    onDataReceived:Fire("Hello, World!")

    -- Disconnect when done
    connection:Disconnect()

    -- Or disconnect all connections
    onDataReceived:Destroy()
    ```

    Advanced usage:
    ```lua
    -- Multiple connections
    local signal = Signal.new()
    
    local connections = {
        signal:Connect(function(value) print("First:", value) end),
        signal:Connect(function(value) print("Second:", value) end)
    }

    -- Fire with multiple arguments
    signal:Fire("test", 123, { foo = "bar" })

    -- Disconnect specific handlers
    connections[1]:Disconnect()

    -- Clean up all connections
    signal:Destroy()
    ```
]=]

local Maid = require(script.Parent.Maid)

local Signal = {}
Signal.__index = Signal

--[=[
    @desc Creates a new Signal instance
    @return Signal - A new Signal instance
]=]
function Signal.new()
    local self = setmetatable({
        _maid = Maid.new(),
        _nextId = 1
    }, Signal)
    return self
end

--[=[
    @desc Connects a callback function to the signal
    @param callback - Function to be called when the signal is fired
    @return table - Connection object with Disconnect method
]=]
function Signal:Connect(callback)
    if type(callback) ~= "function" then
        error("Callback must be a function")
    end

    local id = self._nextId
    self._nextId = id + 1

    local connection = {
        Id = id,
        Callback = callback,
        Connected = true,
        Disconnect = function(self)
            self.Connected = false
        end
    }

    self._maid:GiveTask(id, connection)
    return connection
end

--[=[
    @desc Fires the signal, calling all connected callbacks with the provided arguments
    @param ... - Arguments to pass to the callback functions
]=]
function Signal:Fire(...)
    for _, connection in pairs(self._maid._tasks) do
        if connection.Connected then
            task.spawn(connection.Callback, ...)
        end
    end
end

--[=[
    @desc Disconnects all connected callbacks from the signal and cleans up resources
]=]
function Signal:Destroy()
    self._maid:Destroy()
    self._maid = nil
    setmetatable(self, nil)
end

-- Alias for Destroy for compatibility
Signal.DisconnectAll = Signal.Destroy

return Signal
